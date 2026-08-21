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
      case "takeNextSharedImage":
        do {
          result(try takeNextSharedImage())
        } catch {
          result(FlutterError(code: "shared_image_inbox", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 受信箱の最も古い画像を 1 枚だけ取り出し、取り出した画像ファイルを削除する。
  /// 戻り値は {"imageBytes": バイト列, "imageContentType": MIME タイプ}。受信箱が空なら nil。
  ///
  /// まとめてではなく 1 枚ずつ取り出すのは、確認フローの途中でアプリが終了しても未処理の画像を
  /// 受信箱に残すためと、複数枚の一括転送によるメモリ圧迫を避けるため。
  /// 取り出したファイルを消すため冪等ではない (同じ画像を二重に取り込まないための仕様)。
  static func takeNextSharedImage() throws -> [String: Any]? {
    guard
      let inboxDirectoryURL = try SharedImageInboxLocation.inboxDirectoryURL(
        hostAppBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
      )
    else {
      return nil
    }
    let imageFileURLs = try FileManager.default.contentsOfDirectory(
      at: inboxDirectoryURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    // ファイル名は Extension が「時刻 + 連番」で付ける (ShareViewController) ため名前順 = 共有順。
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
    for imageFileURL in imageFileURLs {
      let imageData: Data
      do {
        imageData = try Data(contentsOf: imageFileURL)
      } catch {
        // 読み込みに失敗したファイルは受信箱に残したままスキップし、次のファイルを試す。
        // 残したファイルは次回の takeNextSharedImage (foreground 復帰時等) で再試行される。
        NSLog("共有画像の読み込みに失敗したためスキップします: %@", error.localizedDescription)
        continue
      }
      // 削除の失敗はスキップせずエラーにする (このファイルを残したまま後続を返すと、
      // 次回の取り出しで残った古いファイルが後から返り、共有した順序が逆転するため)。
      // 最古のファイルは次回の呼び出しで再試行される。
      try FileManager.default.removeItem(at: imageFileURL)
      return [
        "imageBytes": FlutterStandardTypedData(bytes: imageData),
        "imageContentType": UTType(filenameExtension: imageFileURL.pathExtension)?.preferredMIMEType ?? "image/jpeg",
      ]
    }
    return nil
  }
}
