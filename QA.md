---
feature: _root
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# QA 全体ガイド

## 対象環境

- debug ビルド = Firebase project `kashakeibo-dev` (release / profile = `kashakeibo-prod`。接続先は GoogleService-Info.plist / google-services.json の配置で切り替わる。lib/main.dart 参照)
- QA は debug ビルド (kashakeibo-dev) に対して行う
- シミュレータは simtunnel によるリモート Simulator を第一候補にする (/ios-simulator skill Phase 1。導入は https://github.com/bannzai/kashakeibo/issues/35 )
- `--dart-define=USE_FIREBASE_EMULATOR=true` の LOCAL flavor は、リモート Simulator からホストマシンの Emulator へ到達できないため simtunnel での QA では使わない

## 起動方法

- `flutter run` (debug。シミュレータの起動・選定は「動作確認手段」参照)
- ビルド検証: `flutter analyze` / `flutter test` / `flutter build ios --no-codesign` / `flutter build apk`

## ログイン方法

- 匿名認証のみ。起動時に SignInResolver が自動で匿名サインインするため、テストアカウント・認証情報は不要
- ユーザーデータはサインインした匿名 uid の `/users/{uid}` 配下に閉じる。アプリを削除して再インストールすると別 uid になりデータは引き継がれない

## 動作確認手段

- シミュレータ管理: /ios-simulator skill を起点にする (リモート simtunnel を優先。ローカルで行う場合は /sim-manager)
- UI 操作・スクリーンショット: /verify-ui-mobile-mcp (mobile-mcp)
- E2E: Maestro は未導入 (https://github.com/bannzai/kashakeibo/issues/19 で整備予定)。導入までは全項目 agent のシミュレータ操作で確認する

### 再現が難しい操作の手順

- **サンプル明細の投入**: debug ビルドで月次一覧中央の月ラベル (例: 「2026年8月」) を**長押し** → 開発者メニューの「サンプル明細を追加」。今月の明細 5 件 (収入 1・支出 3・計算対象外 1) が入る。冪等ではなく実行のたびに 5 件追加される (lib/features/debug/README.md)
- **重複候補の作り込み**: 重複候補の条件は「両方が支出・計算対象外でない・同一金額・取引日の差 3 日以内・正規化した店名が一致または包含」(lib/entity/transaction.dart の isDuplicateCandidate)。「サンプル明細を追加」を 2 回実行すると支出 3 件分の候補ができる。手動入力で同額・同店名の支出を 2 件登録してもよい。計算対象外の「鳥貴族 (重複疑い)」サンプルは候補にならない点に注意

## 実行ナレッジ

（まだ知見なし。run-qa が実行中の flaky・落とし穴の知見を蓄積する。運用ルールは ~/.claude/skills/setup-qa/references/qa-md-format.md を参照）

## 横断確認項目

仕様: https://github.com/bannzai/kashakeibo/issues/3 (Firebase 接続基盤・匿名認証の受け入れ条件)

## 1. 起動・サインイン

- [ ] **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) にローディングを経て月次一覧が表示され、登録操作なしで使い始められる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **2 回目以降の起動**: アプリを終了して再起動しても、同じユーザーのデータ (投入済み明細) が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **サインイン失敗時のエラー表示**: サインインに失敗するとエラーメッセージが加工されずに表示され、リトライボタンで再試行できる
  - 自動化: todo (初回起動時にネットワークを遮断する等の失敗状態の作り込み手段が未整備)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) にローディングを経て月次一覧が表示され、登録操作なしで使い始められる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **2 回目以降の起動**: アプリを終了して再起動しても、同じユーザーのデータ (投入済み明細) が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **サインイン失敗時のエラー表示**: サインインに失敗するとエラーメッセージが加工されずに表示され、リトライボタンで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

## 機能別 QA.md

- [monthly (月次一覧)](lib/features/monthly/QA.md)
- [manual_entry (手動明細入力)](lib/features/manual_entry/QA.md)
- [settings (設定)](lib/features/settings/QA.md)

## QA 対象外

- appstore_screenshot: ストアスクショ生成用の固定データ Widget。参照元は scripts/generate_screenshots/ と test/ のみで、アプリ内のどの画面からも到達できない
- image_upload: HTTP クライアントのみで画面が無い (lib/features/image_upload/README.md に明記)。撮影・取込フロー実装時に利用側 feature の QA.md で確認する
- debug: kDebugMode ガード配下 (lib/features/monthly/monthly_page.dart) の開発者メニューで release ビルドに含まれない。QA の状態作り込み手段として「再現が難しい操作の手順」に記載
