// Safari・写真アプリなどの共有シートから画像を受け取る共有 Extension。
// 独自 UI は持たず、受け取った画像を App Group の受信箱 (SharedImageInboxLocation) へ保存してから
// ホストアプリを URL スキームで開き、アプリ側の撮影フロー (確認・修正画面) に合流させる
// (lib/features/share_import/README.md)。
import UIKit
import UniformTypeIdentifiers

/// 共有シートの入口となる ViewController (Info.plist の NSExtensionPrincipalClass)。
class ShareViewController: UIViewController {
  // Worker がアップロードを受け付ける画像形式 (workers/image/src/handler.ts の imageContentTypeExtensions)。
  // これ以外の形式 (GIF・TIFF 等) は JPEG に変換して受信箱へ入れる。
  private static let acceptedImageTypes: [UTType] = [.jpeg, .png, .webP, .heic]

  // これ以上大きい画像は JPEG に再圧縮して Worker の上限 (20MB) と通信量を抑える。
  private static let maxImageBytesWithoutReencoding = 10 * 1024 * 1024

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task {
      await importSharedImages()
    }
  }

  /// 共有された画像をすべて受信箱へ保存し、ホストアプリを開いて Extension を終了する。
  /// 共有シートの操作ごとに実行する副作用のため冪等ではない。
  private func importSharedImages() async {
    let hostAppBundleIdentifier = Self.hostAppBundleIdentifier()
    do {
      guard
        let inboxDirectoryURL = try SharedImageInboxLocation.inboxDirectoryURL(
          hostAppBundleIdentifier: hostAppBundleIdentifier
        )
      else {
        throw ShareExtensionError.appGroupUnavailable
      }
      let imageAttachments = (extensionContext?.inputItems ?? [])
        .compactMap { $0 as? NSExtensionItem }
        .flatMap { $0.attachments ?? [] }
        .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
      guard !imageAttachments.isEmpty else {
        throw ShareExtensionError.noImage
      }
      // 受信箱のファイル名は「時刻 + 連番」にし、ホストアプリが共有した順に取り出せるようにする。
      let batchPrefix = String(format: "%.0f", Date().timeIntervalSince1970 * 1000)
      for (index, attachment) in imageAttachments.enumerated() {
        let (imageData, fileExtension) = try await Self.loadImage(from: attachment)
        let imageFileURL = inboxDirectoryURL.appendingPathComponent(
          "\(batchPrefix)-\(String(format: "%03d", index)).\(fileExtension)"
        )
        try imageData.write(to: imageFileURL, options: .atomic)
      }
      openHostApp(hostAppBundleIdentifier: hostAppBundleIdentifier)
    } catch {
      extensionContext?.cancelRequest(withError: error)
    }
  }

  /// 添付 1 件を画像のバイト列と拡張子にする。
  /// Worker が受け付ける形式ならそのまま、それ以外と大きすぎる画像は JPEG に変換する。
  private static func loadImage(from attachment: NSItemProvider) async throws -> (Data, String) {
    let loadedImage = try await loadImageData(from: attachment)
    let isAcceptedType = loadedImage.type.map { type in acceptedImageTypes.contains { type.conforms(to: $0) } } ?? false
    if isAcceptedType, loadedImage.data.count <= maxImageBytesWithoutReencoding,
      let fileExtension = loadedImage.type?.preferredFilenameExtension
    {
      return (loadedImage.data, fileExtension)
    }
    guard let image = UIImage(data: loadedImage.data), let jpegData = image.jpegData(compressionQuality: 0.85) else {
      throw ShareExtensionError.unreadableImage
    }
    return (jpegData, "jpg")
  }

  /// 添付から画像のバイト列と型を読み出す。ファイル表現 (写真アプリ・Safari の画像) を優先し、
  /// 無ければ item (UIImage / URL / Data) として読む。
  private static func loadImageData(from attachment: NSItemProvider) async throws -> (data: Data, type: UTType?) {
    let imageTypeIdentifier =
      attachment.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true } ?? UTType.image.identifier
    if let fileRepresentation = try? await loadFileRepresentation(from: attachment, typeIdentifier: imageTypeIdentifier) {
      return fileRepresentation
    }
    let item = try await attachment.loadItem(forTypeIdentifier: imageTypeIdentifier)
    if let fileURL = item as? URL {
      let data = try Data(contentsOf: fileURL)
      return (data, UTType(filenameExtension: fileURL.pathExtension))
    }
    if let image = item as? UIImage, let pngData = image.pngData() {
      return (pngData, .png)
    }
    if let data = item as? Data {
      return (data, UTType(imageTypeIdentifier))
    }
    throw ShareExtensionError.unreadableImage
  }

  /// loadFileRepresentation は completion の間だけ有効な一時ファイルを渡すため、その場で読み切る。
  private static func loadFileRepresentation(
    from attachment: NSItemProvider,
    typeIdentifier: String
  ) async throws -> (data: Data, type: UTType?) {
    try await withCheckedThrowingContinuation { continuation in
      attachment.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { fileURL, error in
        guard let fileURL else {
          continuation.resume(throwing: error ?? ShareExtensionError.unreadableImage)
          return
        }
        do {
          continuation.resume(returning: (try Data(contentsOf: fileURL), UTType(filenameExtension: fileURL.pathExtension)))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// ホストアプリを URL スキームで開き、Extension を完了する。
  /// Extension は UIApplication.shared と open(_:options:completionHandler:) を直接呼べない
  /// (APPLICATION_EXTENSION_API_ONLY) ため、responder chain を辿って UIApplication を見つけ、
  /// セレクタ経由で open を呼ぶ (receive_sharing_intent 等の共有 Extension 実装と同じ手法)。
  private func openHostApp(hostAppBundleIdentifier: String) {
    guard let hostAppURL = SharedImageInboxLocation.hostAppURL(hostAppBundleIdentifier: hostAppBundleIdentifier) else {
      extensionContext?.cancelRequest(withError: ShareExtensionError.appGroupUnavailable)
      return
    }
    // -[UIApplication openURL:options:completionHandler:] (iOS 10+)。iOS 18 では旧来の openURL: が効かないためこちらを使う。
    // C 呼び出しでは Swift の URL が NSURL へ自動ブリッジされないため、NSURL に明示変換して渡す。
    let openURLSelector = NSSelectorFromString("openURL:options:completionHandler:")
    typealias OpenURLFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, Any?) -> Void
    var responder: UIResponder? = self
    while let currentResponder = responder {
      if currentResponder.responds(to: openURLSelector), let openURLMethod = currentResponder.method(for: openURLSelector) {
        unsafeBitCast(openURLMethod, to: OpenURLFunction.self)(
          currentResponder,
          openURLSelector,
          hostAppURL as NSURL,
          [:],
          nil
        )
        break
      }
      responder = currentResponder.next
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  /// Extension の bundle ID (ホストアプリの bundle ID + ".ShareExtension") からホストアプリの bundle ID を得る。
  private static func hostAppBundleIdentifier() -> String {
    let extensionBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    guard let lastDotIndex = extensionBundleIdentifier.lastIndex(of: ".") else {
      return extensionBundleIdentifier
    }
    return String(extensionBundleIdentifier[..<lastDotIndex])
  }
}

/// 共有 Extension で発生する失敗。エラー文はそのままシステムの失敗表示に渡す。
enum ShareExtensionError: LocalizedError {
  /// App Group コンテナが使えない (entitlements の設定漏れ)。
  case appGroupUnavailable

  /// 共有された項目に画像が無い。
  case noImage

  /// 画像として読み出せなかった。
  case unreadableImage

  var errorDescription: String? {
    switch self {
    case .appGroupUnavailable:
      return "App Group が使えないため画像を渡せませんでした"
    case .noImage:
      return "共有された項目に画像がありません"
    case .unreadableImage:
      return "画像を読み込めませんでした"
    }
  }
}
