---
feature: _root
verification: mobile-mcp
last_verified_commit: cd9dbad802effa2adefc8f309f88c7cce80bf5aa
last_verified_at: 2026-09-01
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
- ユーザーデータはサインインした匿名 uid の `/users/{uid}` 配下に閉じる。iOS では Firebase Auth の認証状態が Keychain に保存されるため、アプリを削除して再インストールしても同じ匿名 uid が復元されることがある。新規 uid (初回起動状態) が必要な時は Simulator を消去する (`xcrun simctl erase <udid>`)、または新しい simtunnel セッション (runner ごと新規) を使う

## 動作確認手段

- シミュレータ管理: /ios-simulator skill を起点にする (リモート simtunnel を優先。ローカルで行う場合は /sim-manager)
- UI 操作・スクリーンショット: /verify-ui-mobile-mcp (mobile-mcp)
- E2E: Maestro を導入済み (issue #19)。主要フローは maestro/flows/ (手動入力 / レシート撮影→登録 / 計算対象からの除外 / 課金導線) にあり、/flutter-maestro skill で実行する。ローカル Simulator は iOS 18.x ランタイム推奨 (26.x は WDA 不安定)。撮影フローは App Check debug token の登録 (workers/image/README.md) が前提。maestro フローが無い項目は agent のシミュレータ操作で確認する

### 再現が難しい操作の手順

- **サンプル明細の投入**: debug ビルドで月次一覧中央の月ラベル (例: 「2026年8月」) を**長押し** → 開発者メニューの「サンプル明細を追加」。今月の明細 5 件 (収入 1・支出 3・計算対象外 1) が入る。冪等ではなく実行のたびに 5 件追加される (lib/features/debug/README.md)
- **重複候補の作り込み**: 重複候補の条件は「両方が支出・計算対象外でない・同一金額・取引日の差 3 日以内・正規化した店名が一致または包含」(lib/entity/transaction.dart の isDuplicateCandidate)。「サンプル明細を追加」を 2 回実行すると支出 3 件分の候補ができる。手動入力で同額・同店名の支出を 2 件登録してもよい。計算対象外の「鳥貴族 (重複疑い)」サンプルは候補にならない点に注意

## 実行ナレッジ

- **simtunnel のリモート Simulator は英語ロケール・UTC 日付**: 画面の文言はすべて l10n の en 値になる。QA.md の項目文が日本語文言を例示していても英語での同等表示で判定してよい (記録時にその旨を書く)。また Simulator の当日はホストマシン (JST) より 1 日前になることがある (2026-08-19 JST の実行時に Simulator は 2026-08-18)。「日付の初期値は今日」のような判定は Simulator の当日を基準にし、Material DatePicker で "Today" の枠線が付く日で確認できる
- **アプリの再起動**: リモートではアプリの削除・再インストールができないため、初回起動の確認はインストール直後の状態で行う。再起動の確認は `bash tmp/qa/wda.sh terminate com.bannzai.kashakeibo` → `launch` で行うが、終了直後に 1 枚撮ってホーム画面が出ていることを確認しないと、再起動後の画面が終了前と同じに見えるだけで再起動の証拠にならない
- **外部ブラウザ (Safari) で開いた URL の確認**: Safari のツールバーのアドレス欄はホスト名だけの短縮表示 (`bannzai.github.io`) で、どのパスを開いたかスクショからは判別できない。アドレス欄をタップして編集状態にすると `elements` に `"name": "URL"` の TextField が現れ、その `value` にフルURLが入るのでこれで判定する。また Simulator 初回起動時の Safari は「Start Page のカスタマイズ」「View Bookmarks, Share Menu, and Open Tabs」といったオンボーディングのポップオーバーを重ねてきて、閉じるまでツールバーの要素が `elements` に出ない (ポップオーバーの `Close` / `close` ボタンをタップして消す)。Safari からアプリへ戻るのは `bash tmp/qa/wda.sh launch com.bannzai.kashakeibo` で、直前に開いていた画面のまま復帰する
- **ローカル Simulator の debug ビルドは App Check の debug token 登録が無いと Worker が 401 になる**: 残量チップ (`GET /analyses/quota`) が表示されず、撮影も通らない。`xcrun simctl spawn <UDID> log show --last 2m --predicate 'process == "Runner"' | grep "App Check debug token"` で token を控え、workers/image/README.md「デバッグビルドでの動作確認」の手順で kashakeibo-dev にだけ登録してからアプリを再起動する。REST API で登録する時は `x-goog-user-project: kashakeibo-dev` ヘッダーが必要 (無いと quota project 未設定の 403)、displayName は 50 文字以内。`xcrun simctl erase` すると debug token が再生成されるため登録し直す (2026-08-20 の paywall QA で発生)
- **simtunnel のリモート Simulator で App Check を通す**: runner の debug ビルドは App Check の Debug provider で、登録済みの debug token が無いと Worker が 401 になり撮影フロー・残量チップが動かない。kashakeibo-dev に登録した token を `~/.config/kashakeibo/appcheck-debug-token-simtunnel.secret` (`FIRAAppCheckDebugToken=<uuid>` の env-file、mode 600。git 管理外) に置き、セッション確立後に `bash ~/.claude/skills/ios-simulator/scripts/ios-wda.sh --session <session> terminate com.bannzai.kashakeibo.dev` → `... launch com.bannzai.kashakeibo.dev --env-file ~/.config/kashakeibo/appcheck-debug-token-simtunnel.secret` で relaunch する (2026-09-02 の PR #79 で確認。token が無い場合の登録は workers/image/README.md の REST API の手順で kashakeibo-dev にだけ行う。igen と同じ運用で、skill への追記は https://github.com/bannzai/castle/issues/803 )。`ios-wda.sh` の座標引数は zsh では `tap $x $y` のように分けて渡す (`"201 447"` の 1 変数は分割されず usage エラーで無視される)
- **Simulator の消去後は mobile-mcp の agent が消える**: `xcrun simctl erase` 後に `mobile_take_screenshot` が `agent is not installed` で失敗する。`mobilecli agent install --device <UDID>` (mobile-mcp が使う mobilecli。`~/.npm/_npx/*/node_modules/mobilecli/bin/` 配下) で再インストールする。その間に `flutter run` が走っていると attach が切れる (`Lost connection to device`) が、アプリ自体はインストール済みなので `xcrun simctl launch` で起動すればよい
- **スナックバーの撮影は mobile-mcp だと間に合わない**: 購入失敗・復元結果などのスナックバーは数秒で消えるため、`mobile_click` → `mobile_save_screenshot` の 2 ツール呼び出しでは消えた後の画面が撮れる。タップと撮影を 1 つのシェルコマンドにまとめる (`mobilecli io tap "x,y" --device <UDID>; sleep 1.2; xcrun simctl io <UDID> screenshot <path>`)
- **キーボードで隠れる要素**: 手動明細入力シートのように autofocus で数字キーボードが出る画面では、画面下部のボタン (登録ボタン等) がキーボードの裏に入り `elements` にも出ない。数字キーボードには改行キーが無いため、`textInputAction: done` を持つ別のテキスト欄 (店名欄) をタップしてから `keys` に改行だけを送ってキーボードを閉じる。日本語キーボードには `done` ボタンが要素として出るのでそれをタップしてもよい。キーボードの開閉で全要素の rect がずれるので、閉じた後に `elements` を取り直してから座標を決める
- **ローカル Simulator の debug ビルドは bundle ID が `com.bannzai.kashakeibo.dev`**: `xcrun simctl launch` / `terminate` / ログ取得はこの ID で行う (`com.bannzai.kashakeibo` ではない)。ビルドは `flutter build ios --simulator --debug` (CI の simulator-session.yml と同じ。dart-define なし) で、`build/ios/iphonesimulator/Runner.app` を `xcrun simctl install` する。ビルドには 15 分程度かかる
- **ローカル Simulator のロケール切替**: `xcrun simctl spawn <UDID> defaults write "Apple Global Domain" AppleLanguages -array ja` (英語は `-array en`) の後にアプリを再起動すると、l10n の表示言語が切り替わる。Simulator 全体の再起動は不要。ホスト macOS が日本語なら Simulator も既定で日本語ロケールになるため、日本語文言で判定する項目はローカルで行う (simtunnel のリモート Simulator は英語ロケール固定)
- **ローカル Simulator は JST**: リモートと違い当日がホストマシンと一致する。デートピッカーの当日セルはアクセシビリティラベルが「22, 2026年8月22日土曜日, 今日」のように「今日」で終わるので、これで初期値が当日かを判定できる
- **フォトライブラリへの画像投入**: `xcrun simctl addmedia <UDID> <画像パス>` で Simulator の写真に追加できる。「記録する」→「写真・スクショから選ぶ」で取り込むと、スクショ取込の明細 (出所チップが「スクショ」「自動取込」) と元画像付きの明細詳細を作れる。解析は Worker の無料スキャンを 1 回消費する (残量チップの数字が 1 減ることで確認できる)
- **スキャン残量 0 の状態は開発者メニューで作る**: 今月のスキャン回数は Cloudflare の Durable Object (`workers/image/src/usage_counter.ts` の `UsageCounter`。インスタンス名 = 年月、キー `scan:uid:{uid}`) に持つ。Firestore ではないため firebase / gcloud CLI では触れず、wrangler にも DO storage を外部から書き換えるコマンドが無い。debug ビルドの開発者メニュー (月ラベル長押し → `lib/features/debug/debug_sheet.dart` の「スキャン残量を使い切る」。issue #67 で整備) から Worker の DEBUG 用カウンタ設定経路を叩いて作る
- **並走レーンの Simulator を掴まない**: `xcrun simctl list devices booted` には他の worktree・他プロジェクトの Simulator も並ぶ。プロジェクトルートで `sim-boot` を実行して出た `DEVICE_UDID` を全操作 (`mobilecli --device`・`xcrun simctl`) に必ず渡す
- **追加ロケール (ko / zh / zh_Hans / zh_Hant) の表示は未検証**: 2026-08-22 の多言語展開 (issue #16 / PR #64) で追加。検査は translate-app-arb の check (キー欠落・プレースホルダー・用語集の機械検査) と訳文の抜き取り目視のみで、シミュレータでの画面表示 (レイアウト崩れ・文字化け・法務リンクの言語) は未検証。各言語ロケールでの run-qa 実施時に確認する

## 横断確認項目

仕様: https://github.com/bannzai/kashakeibo/issues/3 (Firebase 接続基盤・匿名認証の受け入れ条件)

## 1. 起動・サインイン

- [x] **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) に登録操作なしで匿名サインインが完了し、オンボーディングが表示される
  - 自動化: auto (maestro/flows/onboarding.yaml)
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

### **初回起動の匿名サインイン**: 初回起動 (アプリ削除後の再インストール直後) に登録操作なしで匿名サインインが完了し、オンボーディングが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

アプリ状態を消去した専用Simulatorで起動し、登録操作なしでSignInResolverの後段にあるオンボーディングが表示された。オンボーディング完了後の再起動では同じ匿名ユーザーの月次画面が表示されることもMaestroで確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/565dabe3-469b-4ecb-a896-31a4573baee2.png" width="320">

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

- [onboarding (初回起動・課金転換ファネル)](lib/features/onboarding/QA.md)
- [monthly (月次一覧)](lib/features/monthly/QA.md)
- [manual_entry (手動明細入力)](lib/features/manual_entry/QA.md)
- [settings (設定)](lib/features/settings/QA.md)
- [paywall (プレミアムのペイウォール・課金)](lib/features/paywall/QA.md)
- [capture (撮影・スクショ取込)](lib/features/capture/QA.md)
- [share_import (共有 Extension からの取り込み)](lib/features/share_import/QA.md)
- [transaction_detail (明細詳細)](lib/features/transaction_detail/QA.md)
- [transaction_search (明細検索)](lib/features/transaction_search/QA.md)
- [audit_log (操作履歴)](lib/features/audit_log/QA.md)

## QA 対象外

- appstore_screenshot: ストアスクショ生成用の固定データ Widget。参照元は scripts/generate_screenshots/ と test/ のみで、アプリ内のどの画面からも到達できない
- image_upload: HTTP クライアントのみで画面が無い (lib/features/image_upload/README.md に明記)。撮影・取込フロー実装時に利用側 feature の QA.md で確認する
- debug: kDebugMode ガード配下 (lib/features/monthly/monthly_page.dart) の開発者メニューで release ビルドに含まれない。QA の状態作り込み手段として「再現が難しい操作の手順」に記載
