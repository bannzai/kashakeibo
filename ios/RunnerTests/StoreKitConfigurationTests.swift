// StoreKit Configuration file (Kashakeibo.storekit) の検証テスト。
// ~/.claude/skills/ios-storekit-testing の雛形を、カシャケイボの実商品 (月額 ¥480 / 年額 ¥3,800 の
// 自動更新サブスクリプション。documents/PROJECT.md の課金設計) に合わせたもの。
// SKTestSession がテストバンドル内の .storekit を読み込むため、App Store Connect にもネットワークにも触れず、
// CLI (xcodebuild test) だけで「商品解決 → 購入 → entitlement 付与」まで確認できる
// (simctl launch には StoreKit Configuration を渡す手段が無いため、CLI からの課金検証はこの経路を使う)。

import StoreKit
import StoreKitTest
import XCTest

final class StoreKitConfigurationTests: XCTestCase {
    private let storeKitConfigurationName = "Kashakeibo"
    private let monthlyProductID = "kashakeibo_premium_monthly_480yen"
    private let annualProductID = "kashakeibo_premium_annual_3800yen"

    /// iOS 26.5 の simulator では xcodebuild test 経由の StoreKit Testing が機能しない既知の問題があるため skip する。
    /// SKTestSession の init は成功するのに設定が適用されず、商品解決が実ストア (sandbox) に落ち、
    /// buyProduct は StoreKitError.notEntitled を投げる (2026-08-15 実測: iOS 26.5 で再現・iOS 26.2 で全項目 pass。
    /// 署名の有無は無関係。Apple Developer Forums でも iOS 26.5 simulator の CI 利用で同様の報告あり)。
    /// 将来の runtime で解消されている可能性があるため、26.5 より新しい runtime ではまず skip を外して実測する
    private func skipOnBrokenSimulatorRuntime() throws {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        try XCTSkipIf(
            version.majorVersion == 26 && version.minorVersion == 5,
            "iOS 26.5 simulator では StoreKit Testing が StoreKitError.notEntitled で機能しない (iOS 26.2 以下の runtime で実行する)"
        )
    }

    /// 月額・年額の商品が .storekit の定義どおりの価格・期間で解決され、無料トライアルは付いていないこと
    func testProductsResolveWithConfirmedPrices() async throws {
        try skipOnBrokenSimulatorRuntime()
        let session = try SKTestSession(configurationFileNamed: storeKitConfigurationName)
        session.resetToDefaultState()
        session.clearTransactions()

        let products = try await Product.products(for: [monthlyProductID, annualProductID])
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        XCTAssertEqual(productsByID.count, 2)
        XCTAssertEqual(productsByID[monthlyProductID]?.price, 480)
        XCTAssertEqual(productsByID[annualProductID]?.price, 3800)
        XCTAssertEqual(productsByID[monthlyProductID]?.subscription?.subscriptionPeriod.unit, .month)
        XCTAssertEqual(productsByID[monthlyProductID]?.subscription?.subscriptionPeriod.value, 1)
        XCTAssertEqual(productsByID[annualProductID]?.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(productsByID[annualProductID]?.subscription?.subscriptionPeriod.value, 1)
        // 無料トライアルは設定していない (無料枠 = 月10スキャンが試用の役割を担う)
        XCTAssertNil(productsByID[monthlyProductID]?.subscription?.introductoryOffer)
        XCTAssertNil(productsByID[annualProductID]?.subscription?.introductoryOffer)
        // 同じサブスクリプショングループ (プランの切替が同一グループ内で行える)
        XCTAssertEqual(
            productsByID[monthlyProductID]?.subscription?.subscriptionGroupID,
            productsByID[annualProductID]?.subscription?.subscriptionGroupID
        )
    }

    /// 年額のテスト購入でトランザクションが成立し、現在の entitlement に現れること
    func testBuyAnnualGrantsEntitlement() async throws {
        try skipOnBrokenSimulatorRuntime()
        // SKTestSession.buyProduct(identifier:options:) は iOS 17+。deployment target (iOS 15) 向けの
        // コンパイルを通すためのガードで、テストは iOS 26.x simulator で実行するので実際に skip されることはない
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("SKTestSession.buyProduct(identifier:) は iOS 17 以降でのみ利用できる")
        }
        let session = try SKTestSession(configurationFileNamed: storeKitConfigurationName)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        _ = try await session.buyProduct(identifier: annualProductID)

        var entitledProductIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                entitledProductIDs.insert(transaction.productID)
            }
        }
        XCTAssertTrue(entitledProductIDs.contains(annualProductID))
    }
}
