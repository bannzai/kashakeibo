# auth (認証)

## 概要

匿名認証スタートの認証基盤 (documents/adr/0001-tech-stack.md)。登録なしで使い始められる。
設定画面から Sign in with Apple / Google へリンクすると、同じ UID のままデータを引き継げる。

## 画面

- `SignInResolver`: 画面ではなく resolver。子 Widget の表示前にサインイン済みであることを保証する
  - 未サインイン (初回起動) なら匿名サインインを実行し、完了までローディングを表示
  - サインイン失敗時はエラーメッセージをそのまま表示し、リトライボタンを出す

## フロー

1. アプリ起動 → `SignInResolver` が `FirebaseAuth.instance.currentUser` を確認
2. null なら `signInAnonymously()` を実行
3. `userChanges()` ストリームでサインイン完了を検知したら子 (MonthlyPage) を表示
4. 設定画面で Apple / Google を選ぶと、現在の匿名 UID へ認証情報をリンクする
5. 別端末で同じ認証情報を選んだ場合は、既存 UID へサインインして保存済みデータを表示する

## データ形式

- ユーザー ID は `currentUserIDProvider` (lib/provider/firebase_user.dart) で参照する
- Firestore のデータはすべて `/users/{userID}` 配下に置き、セキュリティルールで本人のみ許可する
  (firebase/firestore.rules、`.claude/rules/firestore-rules-simplicity.md`)

## 制約

- 匿名のまま端末を失うとデータも失われるため、設定画面の先頭に「機種変更に備えてバックアップ」導線を表示する
- Firebase Authentication の Apple / Google プロバイダと、各プラットフォームの OAuth 設定が必要
