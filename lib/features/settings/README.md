# settings（設定）

## 概要

匿名ユーザーのデータ寿命を守るための Apple / Google アカウントへのリンク、プラン (無料 / プレミアム) の表示とペイウォールへの導線、操作履歴 (`features/audit_log`) への導線、アカウント削除、法務ドキュメントへの導線を提供する。

## 画面

- `SettingsPage`（月次一覧の設定アイコンから表示する）
  - 匿名ユーザーには「未設定」のバックアップカードと Apple / Google のリンクボタンを表示する
  - リンク済みユーザーには「設定済み」と表示し、未リンクのプロバイダだけを追加でリンクできる
  - プラン行に現在のプラン (無料 / プレミアム。`isPremiumProvider`) を表示し、タップでペイウォール (`features/paywall`) を開く
  - 操作履歴の行をタップすると、明細の訂正削除履歴の画面 (`features/audit_log`) を開く
  - 利用規約、プライバシーポリシー、特定商取引法に基づく表示をタップすると、端末の既定ブラウザで GitHub Pages の該当ページを開く。英語環境ではプライバシーポリシーの英語版を開く
  - 画面下部から、確認ダイアログを経てアカウントを削除できる

## フロー

### アカウントリンク

1. 月次画面の設定ボタンから設定画面を開く
2. Apple または Google を選ぶ
3. 匿名 UID に明細がある場合は、既存アカウントへ切り替わると匿名データへアクセスできなくなる旨を確認する
4. 認証情報が現在の匿名 UID に未使用なら、その UID へリンクする
5. 認証情報が既存 UID にリンク済みなら、その UID へサインインして保存済みデータを表示する

### アカウント削除

1. 「アカウントを削除」をタップし、確認ダイアログで削除を確定する
2. リンク済みプロバイダで再認証し、R2 の全画像・Firestore の明細と操作履歴・ユーザードキュメント・Firebase Auth アカウントを削除する
3. 匿名ユーザーで Firebase Auth の削除が recent-login を要求した場合は、保存データ削除後にサインアウトして新しい匿名アカウントで再開する

### 法務ドキュメント

1. 表示する法務ドキュメントをタップする
2. 端末の既定ブラウザで内容を確認する

## データ形式

- リンク状態は Firebase Auth の `User.isAnonymous` と `User.providerData` を唯一の情報源にする
- 家計簿データはリンク前後で同じ Firebase Auth UID を使うため、Firestore 側の移行は行わない
- 法務ドキュメントの公開先は `https://bannzai.github.io/kashakeibo/` で、Firestore などの永続データは使用しない

## 有効期限・制約

- Firebase Authentication の Apple / Google プロバイダ設定と、各プラットフォームの OAuth 設定が必要
- Android の Google 認証には、Web OAuth client を含む `google-services.json` を Firebase から再取得し、生成される `default_web_client_id` を `google_sign_in` が読める状態にする
- R2 画像は Firebase Auth ユーザーを削除する前に、画像 Worker の `DELETE /images` で削除する
- 外部ブラウザを開けなかった場合は、起動処理が返したエラーを画面下部に表示する
