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
3. 認証情報が現在の匿名 UID に未使用なら、その UID へリンクする
4. 認証情報が既存 UID にリンク済みなら、その UID へサインインして保存済みデータを表示する
5. アカウント削除時はリンク済みプロバイダで再認証し、Firestore の明細・ユーザードキュメント・Firebase Auth アカウントを削除する

## データ形式

- リンク状態は Firebase Auth の `User.isAnonymous` と `User.providerData` を唯一の情報源にする
- 家計簿データはリンク前後で同じ Firebase Auth UID を使うため、Firestore 側の移行は行わない

## 有効期限・制約

- Firebase Authentication の Apple / Google プロバイダ設定と、各プラットフォームの OAuth 設定が必要
- 現時点でアプリが保存するユーザーデータは Firestore の `users/{userID}/transactions` と `users/{userID}`。R2 画像機能を追加する際は、同じ削除操作から Worker の削除 API も呼ぶ
