---
feature: settings
verification: mobile-mcp
last_verified_commit: 290350f79dfaf68d1ebf1ecce2d1a18df72e6103
last_verified_at: 2026-08-23
---

# settings QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/18 (GitHub Pages 有効化と法務ドキュメント導線の受け入れ条件) / https://github.com/bannzai/kashakeibo/issues/11 (匿名認証 → アカウントリンクの受け入れ条件)
- 関連: lib/features/settings/README.md / https://github.com/bannzai/kashakeibo/pull/33 (アカウント連携とバックアップ導線)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | https://bannzai.github.io/kashakeibo/ で index・Terms・PrivacyPolicy・SpecifiedCommercialTransactionAct-ja・AccountDeletion が 200 を返す | 法務ページの配信確認 |
| S2 | 設定画面に利用規約・プライバシーポリシー・特商法表記へのリンクがある | 設定画面の表示 / 法務ドキュメントを開く |
| S3 | en-US ストアメタデータの privacy_url 用に英語版法務ページを用意する | 英語環境のプライバシーポリシー / ストアメタデータの privacy_url |
| S4 | 匿名ユーザーに Apple / Google でのバックアップ (アカウントリンク) 導線を提示し、Google はサインイン UI まで到達できる (issue #11 / issue #66) | バックアップカードの表示 / Apple サインインシートの表示 / Google サインインシートの表示 |
| S5 | 選択したアカウントが別端末で利用中の可能性がある場合、匿名データへアクセスできなくなる旨の確認ダイアログを出す | Apple サインインシートの表示 / Google サインインシートの表示 (どちらもリンク導線のタップ直後に確認ダイアログ「この端末のデータを確認」が出ることを 2026-08-22 に確認した) |
| S6 | プラン行からペイウォールを開ける | プラン行からペイウォール |
| S7 | アカウント削除は確認ダイアログを挟み、実行するとアカウントと明細が完全に削除される | アカウント削除の確認ダイアログ / アカウント削除の実行 |

## 1. 設定画面

- [x] **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / ロケールに応じたプライバシーポリシー / SpecifiedCommercialTransactionAct-ja) が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く
  - 自動化: manual (シミュレータの言語切替を伴うため agent のシミュレータ操作で確認する)
- [x] **日本語環境のプライバシーポリシー**: 端末の言語を日本語にした状態でプライバシーポリシーをタップすると PrivacyPolicy (日本語版) が開く
  - 自動化: manual (シミュレータの言語切替を伴うため agent のシミュレータ操作で確認する。simtunnel のリモート Simulator は英語ロケール固定のため、本項目はローカル Simulator で行う)
- [x] **戻る操作**: 戻るボタンで月次一覧へ戻る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **外部ブラウザ起動失敗時のエラー表示**: 外部ブラウザを開けなかった場合、起動処理が返したエラーメッセージが加工されずスナックバーで画面下部に表示される (lib/features/settings/README.md)
  - 自動化: todo (Simulator で Safari の起動を失敗させる状態の作り込み手段が未整備。test/widget_test.dart の設定画面テストは openExternalUri を差し替えるため、失敗経路はウィジェットテストで代替できる見込み)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

月次一覧の右上の設定アイコンから遷移した設定画面。タイトル「設定」の下に、バックアップカード → プラン行 → 法務ドキュメントのカードの順で並び、法務カードには「利用規約」「プライバシーポリシー」「特定商取引法に基づく表示」の 3 行 (それぞれ右端に > のシェブロン) が表示された。最下部に「アカウントを削除」がある。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/5f15720f-ee6b-457a-ab0c-5b4becbceca5.png" width="320">

</details>

### **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / ロケールに応じたプライバシーポリシー / SpecifiedCommercialTransactionAct-ja) が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

3 行とも既定ブラウザ (Safari) が起動し、法務ドキュメントの本文が表示された。Safari のアドレス欄はホスト名だけの短縮表示 (`bannzai.github.io`) になるため、アドレス欄をタップして編集状態にし、UI ツリーの「アドレス」TextField の value で読み取ったフル URL で判定した。日本語ロケールなのでプライバシーポリシーは ja 版 (`PrivacyPolicy`) が開く:

```text
利用規約               → https://bannzai.github.io/kashakeibo/Terms
プライバシーポリシー   → https://bannzai.github.io/kashakeibo/PrivacyPolicy
特定商取引法に基づく表示 → https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
```

左から 利用規約 (見出し「カシャケイボ利用規約」と本文・第1条(定義))、プライバシーポリシー (見出し「プライバシーポリシー」と日本語本文・「収集する利用者情報および収集方法」)、特定商取引法に基づく表示 (見出し「特定商取引法に基づく表示」と問い合わせ先・販売価格・支払方法) をタップした結果。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/451a82c6-7087-4744-8008-130706701c4f.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/42e98760-e62b-4b99-a81f-c4e916357365.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/7979ac83-96b0-4bcc-b4f7-09372c802e4d.png" width="320">

アドレス欄を編集状態にしてフル URL を読んだ状態 (利用規約 / 特定商取引法に基づく表示):

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/f32e18fe-190c-4154-a1e7-b001a1541ffd.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/f080ec5a-2e77-40f5-baa7-129b70556d8b.png" width="320">

Safari からアプリへ戻るには `xcrun simctl launch <UDID> com.bannzai.kashakeibo.dev` を実行する (設定画面を開いたまま復帰する)。初回起動時の Safari は「ブックマーク、共有メニュー、および開いているタブを表示」等のオンボーディングのポップオーバーを重ねてきて、閉じるまでツールバーの要素が UI ツリーに出ない。

</details>

### **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5) の debug ビルド。`xcrun simctl spawn <UDID> defaults write "Apple Global Domain" AppleLanguages -array en` でロケールを英語に切り替え、アプリを再起動してから確認した (設定画面の文言が "Settings" / "Terms of Service" / "Privacy Policy" / "Commercial Transaction Disclosure" / "Delete account" になっていることで切り替わりを確認)。

Privacy Policy 行をタップすると Safari が `https://bannzai.github.io/kashakeibo/PrivacyPolicy-en` を開き (アドレス欄を編集状態にして UI ツリーの「アドレス」TextField の value で確認)、英語版プライバシーポリシー本文が表示された。見出し "Privacy Policy" と、`bannzai (the "Provider") establishes this Privacy Policy...` で始まる英語の本文・"User Information We Collect and How We Collect It" の節が読める。アプリ側のロケール分岐 (英語なら PrivacyPolicy-en) が期待どおり動いている。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/d03854c7-6b32-4336-a7a2-67cee907a643.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/9ca4d230-7056-4a7b-bc2f-b23f680cdcf8.png" width="320">

</details>

### **日本語環境のプライバシーポリシー**: 端末の言語を日本語にした状態でプライバシーポリシーをタップすると PrivacyPolicy (日本語版) が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。ホスト macOS が日本語のため Simulator も既定で日本語ロケールになる (設定画面の文言が「設定」「利用規約」「プライバシーポリシー」等の日本語表示)。

プライバシーポリシー行をタップすると Safari が `https://bannzai.github.io/kashakeibo/PrivacyPolicy` (`-en` の付かない日本語版) を開き、見出し「プライバシーポリシー」と `bannzai（以下「提供者」といいます。）は、提供者の提供するサービス「カシャケイボ」...` で始まる日本語本文・「収集する利用者情報および収集方法」の節が表示された。

ロケールの切り替えは `xcrun simctl spawn <UDID> defaults write "Apple Global Domain" AppleLanguages -array ja` (英語にするときは `-array en`) の後にアプリを再起動する。simtunnel のリモート Simulator は英語ロケール固定でこの確認ができないため、本項目はローカル Simulator で行う。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/42e98760-e62b-4b99-a81f-c4e916357365.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/23cd4c5d-c585-4429-95de-bcf979f45e6c.png" width="320">

</details>

### **戻る操作**: 戻るボタンで月次一覧へ戻る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

設定画面の AppBar 左上の戻るボタンをタップすると月次一覧へ戻り、月ラベル (2026年8月)・サマリー (支出 ¥10,460 / 収入 ¥300,000 / 残り ¥289,540)・カテゴリ内訳・明細一覧が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/e0963dae-378d-4fc2-accf-ede82bddfb74.png" width="320">

</details>

### **外部ブラウザ起動失敗時のエラー表示**: 外部ブラウザを開けなかった場合、起動処理が返したエラーメッセージが加工されずスナックバーで画面下部に表示される (lib/features/settings/README.md)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. アカウント (バックアップ・プラン・削除)

2026-08-22 の見直しで追加 (PR #33 のアカウント連携・削除、PR #56 のプラン行)。設定画面が法務ドキュメント導線のみからアカウント管理画面へ拡張された。

- [x] **バックアップカードの表示**: 匿名ユーザーの設定画面に「バックアップ」カード (状態: 未設定) と Apple / Google のリンク導線、説明文 (機種変更してもデータが引き継げます) が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **Apple サインインシートの表示**: Apple のバックアップ導線をタップすると Apple のサインイン UI が表示される (実 Apple ID の入力・リンク完了までは行わない)
  - 自動化: manual (シート表示までを agent のシミュレータ操作で確認する。リンク完了は実アカウントが必要なため対象外)
  - ⏭️ スキップ: Apple Account 未サインインの Simulator では、SiwA の資格情報シートの代わりに iOS のアラート「Apple Accountにサインインしてください」が出るため、シート本体を表示できない。アプリが SiwA を起動するところまでは確認済み (アプリの確認ダイアログ → `AuthorizationError Code=1000`)。シート表示の確認には Apple Account を設定した Simulator か実機が必要
- [x] **Google サインインシートの表示**: Google のバックアップ導線をタップすると Google のサインイン UI が表示される (実アカウントの入力・リンク完了までは行わない)
  - 自動化: manual (同上)
  - ✅ 2026-08-22 は `PlatformException(google_sign_in, Your app is missing support for the following URL schemes: ...)` で失敗していた。真因は `Copy GoogleService-Info.plist` ビルドフェーズの位置で、REVERSED_CLIENT_ID を URL スキームへ追記する処理が Xcode の Info.plist 生成に上書きされていた (issue #66 / PR #70 で修正)。修正後の 2026-08-23 に再実行して解消を確認した
  - 機械検査: `ios/RunnerTests/GoogleSignInURLSchemeTests.swift` がビルド済み Runner.app の Info.plist に REVERSED_CLIENT_ID の URL スキーム・GIDClientID・共有 Extension のスキームが揃っているかを検証する
- [x] **プラン行からペイウォール**: 「プラン」行に現在のプランが表示され、タップするとペイウォールが開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **アカウント削除の確認ダイアログ**: 「アカウントを削除」をタップすると確認ダイアログ (「アカウントを削除しますか？」・完全に削除され元に戻せない旨) が表示され、キャンセルすると何も起きない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **アカウント削除の実行**: 確認ダイアログで「削除する」を実行すると、明細データが消えて初期状態 (新しい匿名ユーザー・明細 0 件) になる
  - 自動化: manual (kashakeibo-dev の匿名ユーザーで実施する。アカウント状態が不可逆に変わるため、その Simulator での他 feature の確認がすべて終わってから最後に実施する)
  - 旧 UID 配下のデータが実際に削除されたことは未確認。確認できているのはアプリ表示が初期状態になったことと、残量チップが 50 回に戻った (= uid が変わった) ことまでで、旧 uid の Firestore ドキュメントと R2 画像が消えたかは Firestore / R2 側を直接見ていない
- [ ] **アカウントリンクの完了とデータ引き継ぎ**: Apple / Google で実際にリンクし、別端末 (または再インストール) で同じアカウントを選ぶと保存済みの明細が引き継がれる
  - 自動化: todo (実 Apple ID / Google アカウントが必要で Simulator の作り込み手段が未整備。リンク処理の分岐は test/provider/account_test.dart でカバー)
- [ ] **ユーザー取得中・失敗時の表示**: Firebase ユーザーの読み込み中はローディング、取得失敗時はエラーが表示される
  - 自動化: todo (状態の作り込み手段が未整備。widget テストで代替できる見込み)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **バックアップカードの表示**: 匿名ユーザーの設定画面に「バックアップ」カード (状態: 未設定) と Apple / Google のリンク導線、説明文 (機種変更してもデータが引き継げます) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。匿名認証のみでリンク未実施の状態。

設定画面の最上部に淡いグリーンの「バックアップ」カードが出て、見出しの右に状態バッジ「未設定」、その下に説明文「アカウントをリンクすると、機種変更してもデータが引き継げます。」、さらに「Appleでリンク」(塗りつぶし) と「Googleでリンク」(白抜き) の 2 ボタンが並んだ。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/5f15720f-ee6b-457a-ab0c-5b4becbceca5.png" width="320">

</details>

### **Apple サインインシートの表示**: Apple のバックアップ導線をタップすると Apple のサインイン UI が表示される (実 Apple ID の入力・リンク完了までは行わない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

左: 「Appleでリンク」をタップすると、まずアプリ側の確認ダイアログ「この端末のデータを確認 / 選択したアカウントが別の端末で利用中の場合、この端末の匿名データにはアクセスできなくなります。必要な明細を確認してから続けてください。」(キャンセル / 続ける) が出た。右: 「続ける」を選ぶと、Sign in with Apple の資格情報シートではなく iOS のアラート「Apple Accountにサインインしてください / “設定”で Apple Account でサインインする必要があります。」(閉じる / 設定) が表示された。

この Simulator は Apple Account 未サインインのため、OS 側で SiwA のシートが出ない。アプリのログにも `Sign in with Apple errored: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1000` が記録されており、アプリが SiwA を起動するところまでは動いている。サインイン UI 本体の表示は Apple Account を設定した端末でしか確認できないため、本項目は「アプリが SiwA を起動する」ところまでの確認に留まる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/0e75777b-cae3-445a-ad73-002977e24af0.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/4552961f-391b-43ad-8c84-c78a8d080d66.png" width="320">

</details>

### **Google サインインシートの表示**: Google のバックアップ導線をタップすると Google のサインイン UI が表示される (実アカウントの入力・リンク完了までは行わない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (JST)

ローカル Simulator (kashakeibo-issue-66-iOS26.5 / iPhone 16 Pro、日本語ロケール) の debug ビルド (bundle ID `com.bannzai.kashakeibo.dev`)。

2026-08-22 の初回実行では Google のサインイン UI が出ずにエラーのスナックバーが表示されて ❌ だった。issue #66 (PR #70) で `Copy GoogleService-Info.plist` ビルドフェーズを Runner ターゲットの最後尾へ移し、REVERSED_CLIENT_ID の URL スキームがビルド済み Info.plist に残るようにした後、再実行して解消を確認した。

左: 「Googleでリンク」をタップすると iOS の確認「"kashakeibo" がサインインのために "accounts.google.com" を使用しようとしています。」が出る (google_sign_in が URL スキームの検査を通過して認証セッションを開始できている)。右: 「続ける」で Google のログイン画面 (accounts.google.com /「project-750726705707」に移動 = kashakeibo-dev のプロジェクト番号) が表示された。エラーのスナックバーは出ない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/1477dd2e-2d66-4dad-9540-7e139d1b0723.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/69d38aae-3136-4e31-947e-778c13412d8c.png" width="320" />

</details>

### **プラン行からペイウォール**: 「プラン」行に現在のプランが表示され、タップするとペイウォールが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。RevenueCat の public API key は注入していないため、プラン表示は常に「無料」になる。

左: 設定画面の「プラン」行。右端に現在のプラン「無料」とシェブロンが出ている。右: 行をタップすると全画面のペイウォールが開き、「今月の無料スキャン 1/50」(この Simulator でスキャンを 1 回消費済み) が表示された。料金カードが「料金プランを取得できませんでした」になっているのは key 未注入ビルドの既定の挙動 (lib/features/paywall/README.md) で、本項目の「タップでペイウォールが開く」の判定には影響しない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/5f15720f-ee6b-457a-ab0c-5b4becbceca5.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/fb4c9e66-2d35-439c-8feb-17a7649ee8d5.png" width="320">

</details>

### **アカウント削除の確認ダイアログ**: 「アカウントを削除」をタップすると確認ダイアログ (「アカウントを削除しますか？」・完全に削除され元に戻せない旨) が表示され、キャンセルすると何も起きない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

左: 設定画面の「アカウントを削除」をタップすると確認ダイアログ「アカウントを削除しますか？ / アカウントと保存済みの明細は完全に削除され、元に戻せません。」(キャンセル / 削除する) が表示された。中: 「キャンセル」を選ぶとダイアログが閉じるだけで設定画面はそのまま (バックアップカードは「未設定」のまま・プランも「無料」のまま)。右: 戻って月次一覧を見ても、支出 ¥10,460 / 収入 ¥300,000 / 残り ¥289,540 と明細一覧がキャンセル前から変化しておらず、削除が実行されていない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/afe7a0dd-9e9a-467d-955f-5a4336bfc0fc.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/ef7e1e4e-2503-4577-91a6-46a326812df2.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b2e1bd2b-05cf-4bd8-8f62-e5bd811afbe2.png" width="320">

</details>

### **アカウント削除の実行**: 確認ダイアログで「削除する」を実行すると、明細データが消えて初期状態 (新しい匿名ユーザー・明細 0 件) になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。実行前の状態は 2026 年 8 月に明細 7 件 (支出 ¥10,460 / 収入 ¥300,000 / 残り ¥289,540)・2026 年 7 月に収入 1 件 (¥250,000)・残量チップ「スキャン残り49回」(スキャンを 1 回消費済み)。

1 枚目: 確認ダイアログで「削除する」をタップした直後。SignInResolver のローディング (円形インジケータ) だけの画面になり、削除 → 匿名再サインインが走っている。2 枚目: 完了後の 2026 年 8 月。支出 ¥0 / 収入 ¥0 / 残り ¥0・「今月の明細はまだありません」で、明細が 1 件も残っていない。3 枚目: 前月の 2026 年 7 月も ¥0 / 明細なしで、当月以外のデータも消えている。

新しい匿名ユーザーになっていることは残量チップで判定した: 削除前は「スキャン残り49回」だったのが削除後は「スキャン残り50回」に戻っている。スキャン回数は Worker が uid ごとに数える (workers/image) ため、同じ uid のままなら 49 回のはずで、50 回に戻ったことが uid が変わった証拠になる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b6e5cf8a-df07-4393-b6ef-e677c6dba415.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/1792842c-4822-4dd4-8887-9fe0e74dd74e.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/ba4e4b5d-fd6a-4a5a-964a-645630ebe667.png" width="320">

**実施順の注意**: この項目を実行するとその Simulator のデータと匿名 uid が失われるため、同じ Simulator で行う他の確認をすべて終えてから最後に実行する。

</details>

### **アカウントリンクの完了とデータ引き継ぎ**: Apple / Google で実際にリンクし、別端末 (または再インストール) で同じアカウントを選ぶと保存済みの明細が引き継がれる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **ユーザー取得中・失敗時の表示**: Firebase ユーザーの読み込み中はローディング、取得失敗時はエラーが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. 配信

- [x] **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す
  - 自動化: manual (curl での機械確認が可能。Maestro ではなくコマンド実行で確認する)
- [x] **ストアメタデータの privacy_url**: fastlane/metadata/en-US/privacy_url.txt が PrivacyPolicy-en を、fastlane/metadata/ja/privacy_url.txt が PrivacyPolicy を指し、en-US 側の URL が HTTP 200 で英語版本文を返す
  - 自動化: manual (ファイル内容と curl での機械確認が可能。コマンド実行で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

この項目は curl での確認のため、画面のスクリーンショットではなく curl の出力を画像化して貼る (mark_verified.sh がチェック済み項目に画像を要求するため)。

ホストマシンから 6 URL に `curl -s -o /dev/null -w '%{http_code} %{url_effective}\n'` を実行した結果、すべて 200 を返した:

```text
200 https://bannzai.github.io/kashakeibo/
200 https://bannzai.github.io/kashakeibo/Terms
200 https://bannzai.github.io/kashakeibo/PrivacyPolicy
200 https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
200 https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
200 https://bannzai.github.io/kashakeibo/AccountDeletion
```

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/9e1a299c-8fab-4e07-a08d-5ed00f1ac8c2.png" width="320">

</details>

### **ストアメタデータの privacy_url**: fastlane/metadata/en-US/privacy_url.txt が PrivacyPolicy-en を、fastlane/metadata/ja/privacy_url.txt が PrivacyPolicy を指し、en-US 側の URL が HTTP 200 で英語版本文を返す

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

この項目はファイル内容と curl での確認のため、コマンド出力を画像化して貼る。

```text
$ cat fastlane/metadata/en-US/privacy_url.txt fastlane/metadata/ja/privacy_url.txt
https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
https://bannzai.github.io/kashakeibo/PrivacyPolicy

$ curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' $(cat fastlane/metadata/en-US/privacy_url.txt)
200 https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
$ curl -s https://bannzai.github.io/kashakeibo/PrivacyPolicy-en | grep -o '<h1[^>]*>[^<]*</h1>' | head -1
<h1 id="privacy-policy">Privacy Policy</h1>
```

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/1f8d2bd5-0959-4c15-a840-c5a48b7952bf.png" width="320">

</details>

</details>
