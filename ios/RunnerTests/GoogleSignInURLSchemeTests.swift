// Google サインインに必要な iOS 側の設定が、アプリバンドルの Info.plist へ実際に入っているかを検証するテスト。
//
// google_sign_in は起動時ではなくサインイン実行時に Info.plist の CFBundleURLTypes を見て
// PlatformException(google_sign_in, Your app is missing support for the following URL schemes: ...) を投げるため、
// 設定漏れはビルドでは検出できず、画面を手で操作するまで気づけない (issue #66)。
// Runner を TEST_HOST にする本テストの Bundle.main はビルド済みの Runner.app であり、
// 「Copy GoogleService-Info.plist」ビルドフェーズが書き込んだ結果をそのまま検査できる。

import XCTest

final class GoogleSignInURLSchemeTests: XCTestCase {
    /// アプリバンドルへコピーされた GoogleService-Info.plist。
    private func googleServiceInfo() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
            "GoogleService-Info.plist が Runner.app に無い (Copy GoogleService-Info.plist ビルドフェーズが動いていない)"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    /// Info.plist の CFBundleURLTypes に登録済みの URL スキーム全件。
    private func registeredURLSchemes() -> [String] {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    /// GoogleService-Info.plist の REVERSED_CLIENT_ID が URL スキームとして登録されている。
    func testReversedClientIDIsRegisteredAsURLScheme() throws {
        let reversedClientID = try XCTUnwrap(
            googleServiceInfo()["REVERSED_CLIENT_ID"] as? String,
            "GoogleService-Info.plist に REVERSED_CLIENT_ID が無い (Firebase の iOS OAuth クライアント未構成か plist が古い)"
        )
        XCTAssertTrue(
            registeredURLSchemes().contains(reversedClientID),
            "REVERSED_CLIENT_ID が Info.plist の CFBundleURLTypes に無いため Google サインインが失敗する。登録済みスキーム: \(registeredURLSchemes())"
        )
    }

    /// 共有 Extension からホストアプリを開く URL スキームが、Google の追加後も残っている。
    func testShareExtensionURLSchemeIsPreserved() throws {
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        XCTAssertTrue(
            registeredURLSchemes().contains("kashakeibo-share-\(bundleID)"),
            "共有 Extension 用の URL スキームが失われている。登録済みスキーム: \(registeredURLSchemes())"
        )
    }

    /// Info.plist の GIDClientID が GoogleService-Info.plist の CLIENT_ID と一致する。
    func testGIDClientIDMatchesGoogleServiceInfo() throws {
        let clientID = try XCTUnwrap(
            googleServiceInfo()["CLIENT_ID"] as? String,
            "GoogleService-Info.plist に CLIENT_ID が無い (Firebase の iOS OAuth クライアント未構成か plist が古い)"
        )
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
            clientID
        )
    }
}
