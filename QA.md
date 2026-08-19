---
feature: _root
verification: mobile-mcp
last_verified_commit: 8a9634107c725e2670c43709dd1ea4493699072f
last_verified_at: 2026-08-19
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

- **simtunnel のリモート Simulator は英語ロケール・UTC 日付**: 画面の文言はすべて l10n の en 値になる。QA.md の項目文が日本語文言を例示していても英語での同等表示で判定してよい (記録時にその旨を書く)。また Simulator の当日はホストマシン (JST) より 1 日前になることがある (2026-08-19 JST の実行時に Simulator は 2026-08-18)。「日付の初期値は今日」のような判定は Simulator の当日を基準にし、Material DatePicker で "Today" の枠線が付く日で確認できる
- **アプリの再起動**: リモートではアプリの削除・再インストールができないため、初回起動の確認はインストール直後の状態で行う。再起動の確認は `bash tmp/qa/wda.sh terminate com.bannzai.kashakeibo` → `launch` で行うが、終了直後に 1 枚撮ってホーム画面が出ていることを確認しないと、再起動後の画面が終了前と同じに見えるだけで再起動の証拠にならない
- **外部ブラウザ (Safari) で開いた URL の確認**: Safari のツールバーのアドレス欄はホスト名だけの短縮表示 (`bannzai.github.io`) で、どのパスを開いたかスクショからは判別できない。アドレス欄をタップして編集状態にすると `elements` に `"name": "URL"` の TextField が現れ、その `value` にフルURLが入るのでこれで判定する。また Simulator 初回起動時の Safari は「Start Page のカスタマイズ」「View Bookmarks, Share Menu, and Open Tabs」といったオンボーディングのポップオーバーを重ねてきて、閉じるまでツールバーの要素が `elements` に出ない (ポップオーバーの `Close` / `close` ボタンをタップして消す)。Safari からアプリへ戻るのは `bash tmp/qa/wda.sh launch com.bannzai.kashakeibo` で、直前に開いていた画面のまま復帰する
- **キーボードで隠れる要素**: 手動明細入力シートのように autofocus で数字キーボードが出る画面では、画面下部のボタン (登録ボタン等) がキーボードの裏に入り `elements` にも出ない。数字キーボードには改行キーが無いため、`textInputAction: done` を持つ別のテキスト欄 (店名欄) をタップしてから `keys` に改行だけを送ってキーボードを閉じる。キーボードの開閉で全要素の rect がずれるので、閉じた後に `elements` を取り直してから座標を決める

## 横断確認項目

仕様: https://github.com/bannzai/kashakeibo/issues/3 (Firebase 接続基盤・匿名認証の受け入れ条件)

## 1. 起動・サインイン

- [x] **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) に登録操作なしで匿名サインインが完了し、月次一覧が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **初回サインイン中のローディング表示**: 匿名サインインが完了するまで SignInResolver がローディングを表示し、未認証のまま月次一覧が出ない
  - 自動化: todo (匿名サインインを遅延させる状態の作り込み手段が未整備。ネットワークを低速化できるローカル Simulator (Network Link Conditioner) なら観測できる見込み)
- [x] **2 回目以降の起動**: アプリを終了して再起動しても、同じユーザーのデータ (投入済み明細) が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **サインイン失敗時のエラー表示**: サインインに失敗するとエラーメッセージが加工されずに表示され、リトライボタンで再試行できる
  - 自動化: todo (初回起動時にネットワークを遮断する等の失敗状態の作り込み手段が未整備)
- [ ] **他ユーザーのデータへのアクセス拒否**: 別の匿名 uid でサインインしたクライアントから `/users/{他人の uid}/transactions` を読み書きしようとすると permission-denied になる (firebase/firestore.rules)
  - 自動化: todo (アプリ UI からは他ユーザーのパスにアクセスできないため、Firebase Emulator 上のルールテスト (2 つの uid で相互アクセス) として整備する。現時点でルールテストは存在しない)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) に登録操作なしで匿名サインインが完了し、月次一覧が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

simtunnel のリモート Simulator ではアプリ削除→再インストールができないため、runner へインストールした直後の初回起動状態 (明細 0 件・"No transactions this month") がそのまま観測できていることを根拠にする。ローディング表示の瞬間はスクショに収められない。

runner の Simulator が英語ロケールのため、英語表示 ("August 2026" / "Spending" / "No transactions this month" / "Enter manually") で確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/e560a189-a695-488f-a8ce-027780140e9a.jpg" width="320">

</details>

### **初回サインイン中のローディング表示**: 匿名サインインが完了するまで SignInResolver がローディングを表示し、未認証のまま月次一覧が出ない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **2 回目以降の起動**: アプリを終了して再起動しても、同じユーザーのデータ (投入済み明細) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した。

manual_entry の QA で 4 件の明細を登録した状態からアプリを終了 → 再起動した。左: 終了直後。ホーム画面に戻りアプリのプロセスが残っていないことを確認した (この確認をしないと、再起動後の画面が終了前の画面と同じに見えるだけで再起動の証拠にならない)。右: 再起動後。サインイン操作なしで同じ匿名ユーザーの明細 4 件 (Salary August / Cash expense / Lawson QA / Past Date Cafe) とサマリー (Spending ¥6,480 / Income ¥300,000 / Balance ¥293,520) が終了前と同じ内容で表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/0709a35d-de93-4a56-b275-8d1042626e46.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/372cbad2-a3a5-42f3-bfaa-98ccaf2f40f9.jpg" width="320">

</details>

### **サインイン失敗時のエラー表示**: サインインに失敗するとエラーメッセージが加工されずに表示され、リトライボタンで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **他ユーザーのデータへのアクセス拒否**: 別の匿名 uid でサインインしたクライアントから `/users/{他人の uid}/transactions` を読み書きしようとすると permission-denied になる (firebase/firestore.rules)

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
