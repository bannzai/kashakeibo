# settings（設定）

## 概要

匿名ユーザーのデータ寿命を守るため、Apple / Google アカウントへのリンクとアカウント削除を提供する。

## 画面

- `SettingsPage`
  - 匿名ユーザーには「未設定」のバックアップカードと Apple / Google のリンクボタンを表示する
  - リンク済みユーザーには「設定済み」と表示し、未リンクのプロバイダだけを追加でリンクできる
  - 画面下部から、確認ダイアログを経てアカウントを削除できる

## フロー

1. 月次画面の設定ボタンから設定画面を開く
2. Apple または Google を選ぶ
3. 匿名 UID に明細がある場合は、既存アカウントへ切り替わると匿名データへアクセスできなくなる旨を確認する
4. 認証情報が現在の匿名 UID に未使用なら、その UID へリンクする
5. 認証情報が既存 UID にリンク済みなら、その UID へサインインして保存済みデータを表示する
6. アカウント削除時はリンク済みプロバイダで再認証し、R2 の全画像・Firestore の明細とユーザードキュメント・Firebase Auth アカウントを削除する

## データ形式

- リンク状態は Firebase Auth の `User.isAnonymous` と `User.providerData` を唯一の情報源にする
- 家計簿データはリンク前後で同じ Firebase Auth UID を使うため、Firestore 側の移行は行わない

## 有効期限・制約

- Firebase Authentication の Apple / Google プロバイダ設定と、各プラットフォームの OAuth 設定が必要
- Android の Google 認証には、Web OAuth client を含む `google-services.json` を Firebase から再取得し、生成される `default_web_client_id` を `google_sign_in` が読める状態にする
- R2 画像は Firebase Auth ユーザーを削除する前に、画像 Worker の `DELETE /images` で削除する
