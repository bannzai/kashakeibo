// 共有 Extension が App Group の受信箱に置いた画像を Flutter へ渡す MethodChannel
// (Dart 側: lib/features/share_import/shared_image_inbox.dart)。
import Flutter
import Foundation
import UniformTypeIdentifiers

/// 受信箱の画像を Flutter へ渡す MethodChannel のハンドラ。
enum SharedImageInbox {
  /// Dart 側 (shared_image_inbox.dart) と一致させるチャネル名。
  static let methodChannelName = "com.bannzai.kashakeibo/shared_image_inbox"

  /// MethodChannel を登録する。AppDelegate の Flutter エンジン初期化時に 1 回呼ぶ。
  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "SharedImageInbox") else {
      return
    }
    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "takeSharedImages":
        do {
          result(try takeSharedImages())
        } catch {
          result(FlutterError(code: "shared_image_inbox", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 受信箱の画像を共有された順にすべて取り出し、取り出した画像ファイルを削除する。
  /// 戻り値の要素は {"imageBytes": バイト列, "imageContentType": MIME タイプ}。
  /// 取り出したファイルを消すため冪等ではない (2 回目の呼び出しは空になる)。同じ画像を二重に取り込まないための仕様。
  static func takeSharedImages() throws -> [[String: Any]] {
    guard
      let inboxDirectoryURL = try SharedImageInboxLocation.inboxDirectoryURL(
        hostAppBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
      )
    else {
      return []
    }
    let imageFileURLs = try FileManager.default.contentsOfDirectory(
      at: inboxDirectoryURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    // ファイル名は Extension が「時刻 + 連番」で付ける (ShareViewController) ため名前順 = 共有順。
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
    var sharedImages: [[String: Any]] = []
    for imageFileURL in imageFileURLs {
      let imageData = try Data(contentsOf: imageFileURL)
      try FileManager.default.removeItem(at: imageFileURL)
      sharedImages.append([
        "imageBytes": FlutterStandardTypedData(bytes: imageData),
        "imageContentType": UTType(filenameExtension: imageFileURL.pathExtension)?.preferredMIMEType ?? "image/jpeg",
      ])
    }
    return sharedImages
  }
}
