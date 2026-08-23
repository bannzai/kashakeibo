# paywall (プレミアムのハードペイウォール)

## 概要

スキャン無料枠 (月 50 回。issue #50 で月 10 回から引き上げ) を超えたユーザーにプレミアム (スキャン月 1,000 回 + 全期間の履歴) の購入を促すハードペイウォール (issue #12)。
課金は RevenueCat (purchases_flutter) で行い、entitlement `premium` の有無でプレミアムを判定する
(documents/adr/0001-tech-stack.md の「課金」、無料枠の設計は documents/PROJECT.md の「課金設計」)。
デザインは design_handoff_kashakeibo/README.md の 9「ペイウォール」に合わせる。
無料枠の強制はサーバー側 (workers/image の `POST /analyses`。無料枠超過かつ entitlement なしで 402) が正で、
本 feature の表示・ガードは体験のための補助 (`.claude/rules/firestore-rules-simplicity.md` の理由と同じ考え方)。

## 画面

- `PaywallPage` (`showPaywall` で全画面ダイアログとして開く。閉じた時の値はプレミアムになったら true)
  - ✕ (閉じる) → 72px のスパークル円 → 見出し「スキャンし放題に」(句読点の整理は issue #54)
  - 無料枠バー「今月の無料スキャン n/50」(無料プランのみ。`monthlyScanQuotaProvider`)
  - 特典 3 点 (スキャンし放題 / 全期間の履歴 / 今後の新機能)
  - 料金カード: 月額 / 年額 (初期選択・推奨。月額 × 12 に対する割引率バッジと月換算価格)。価格はストアが解決した `StoreProduct.priceString` をそのまま表示する
  - CTA「プレミアムを始める」(選択中のパッケージを購入) → 「いつでも解約できます · 購入の復元」
  - 自動更新の説明とフェアユースの注記 (「スキャンし放題」と月次上限 `monthlyPremiumScanLimit` を両立させる開示)、利用規約・プライバシーポリシーへのリンク (サブスクリプションの表示要件)
  - 既にプレミアムのユーザーには「プレミアム利用中」の表示だけを出し、料金カード・CTA は出さない
  - Offering が取得できない (RevenueCat 未設定・通信失敗) 場合はその旨またはエラー文をそのまま表示する
- 残量チップ (`features/monthly` のセクション行) と「記録する」シート下部 (`features/capture` の `AddRecordSheet`) の残量文言は `scan_quota_label.dart` で共用する

## フロー

1. 導線 (残量チップ / 記録するシートで残量 0 の「カメラで撮影」/ 設定のプラン行 / 撮影フローで解析が 402 / 無料範囲より古い月への月送り) からペイウォールを開く。`showPaywall` の `trigger` で導線を Analytics に記録する
2. 料金カードを選び「プレミアムを始める」でストアの購入シートを開く (`purchasePremiumPackageProvider`)。キャンセルは何も表示せず開いたまま、失敗はエラー文をそのまま表示する
3. 購入・復元後にプレミアムの entitlement が有効なら完了メッセージを出して true で閉じる。撮影フローは true を受けて同じ画像で解析をやり直す
4. 「購入の復元」はストアの購入履歴から entitlement を復元する (`restorePurchasesProvider`)。復元できる購入が無ければその旨を表示する

## データ形式

- 無料プランの履歴範囲: 当月を含む直近 3 ヶ月 (`free_plan_history_limit.dart`)。それより古い月への月送り (features/monthly) でペイウォールを開く。履歴は LLM 原価が発生しない経路のためサーバー強制はせず UI ガードのみ
- プレミアム判定: `CustomerInfo.entitlements.active` に `premium` (`lib/utils/purchase/purchase.dart` の `premiumEntitlementIdentifier`) が含まれるか (`lib/provider/purchase.dart` の `isPremiumProvider`)。Firestore には持たない
- 商品: App Store / Google Play / RevenueCat に同じ識別子で登録する `kashakeibo_premium_monthly_480yen` (月額 ¥480) / `kashakeibo_premium_annual_3800yen` (年額 ¥3,800)。RevenueCat の Current Offering の monthly / annual パッケージとして取得する
- app user ID: Firebase uid。サインイン完了後に `Purchases.logIn(uid)` で揃え (`features/auth` の `SignInResolver`)、Worker が同じ uid で RevenueCat の entitlement を検証する (`workers/image/src/entitlement.ts`)

## 有効期限・制約

- RevenueCat の public API key は `--dart-define` で注入する (`REVENUECAT_PUBLIC_API_KEY_IOS` / `REVENUECAT_PUBLIC_API_KEY_ANDROID`。debug ビルドは Test Store の `REVENUECAT_TEST_STORE_API_KEY`)。未注入のビルドでは SDK を初期化せず、ペイウォールは「料金プランを取得できませんでした」になる
- 無料枠の残量は Worker から取得するため、Worker に接続できないビルドでは残量チップを表示しない (撮影自体は Worker 側の判定に任せる)
- 課金の動作確認は StoreKit Configuration + SKTestSession (`/ios-storekit-testing`) か RevenueCat Test Store で行う。シミュレータで起動したアプリは実ストア (Sandbox) に接続するため商品が解決されない
