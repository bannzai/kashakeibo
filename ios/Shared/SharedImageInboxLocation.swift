// 共有 Extension とホストアプリ (Runner) の両ターゲットにコンパイルされ、共有画像の受け渡し場所を 1 箇所で定義する。
// 受け渡しは App Group コンテナ内のディレクトリ (受信箱) 経由で行う:
//   1. 共有 Extension が受け取った画像を受信箱へファイルとして書く
//   2. Extension が URL スキームでホストアプリを開く
//   3. ホストアプリは起動時・foreground 復帰時に受信箱のファイルを Flutter へ渡して削除する
//     (lib/features/share_import/README.md)
// App Group ID・URL スキームはホストアプリの bundle ID (APP_BUNDLE_IDENTIFIER。dev / prod で異なる) から導出し、
// entitlements (group.$(APP_BUNDLE_IDENTIFIER)) と Info.plist の CFBundleURLSchemes と一致させる。
import Foundation

/// 共有 Extension とホストアプリの間で画像を受け渡す受信箱の場所。
enum SharedImageInboxLocation {
  /// App Group コンテナ内の受信箱ディレクトリ名。
  static let inboxDirectoryName = "shared-images"

  /// ホストアプリを開く URL スキームの接頭辞。実際のスキームは "\(接頭辞)-\(ホストアプリの bundle ID)"。
  static let hostAppURLSchemePrefix = "kashakeibo-share"

  /// ホストアプリの bundle ID に対応する App Group ID (entitlements の group.$(APP_BUNDLE_IDENTIFIER) と同じ値)。
  static func appGroupIdentifier(hostAppBundleIdentifier: String) -> String {
    "group.\(hostAppBundleIdentifier)"
  }

  /// ホストアプリを開く URL。共有 Extension から呼び出す。
  static func hostAppURL(hostAppBundleIdentifier: String) -> URL? {
    URL(string: "\(hostAppURLSchemePrefix)-\(hostAppBundleIdentifier)://import")
  }

  /// 受信箱ディレクトリの URL。無ければ作成する (冪等)。App Group が使えない構成では nil。
  static func inboxDirectoryURL(hostAppBundleIdentifier: String) throws -> URL? {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier(hostAppBundleIdentifier: hostAppBundleIdentifier)
      )
    else {
      return nil
    }
    let inboxDirectoryURL = containerURL.appendingPathComponent(inboxDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: inboxDirectoryURL, withIntermediateDirectories: true)
    return inboxDirectoryURL
  }
}
