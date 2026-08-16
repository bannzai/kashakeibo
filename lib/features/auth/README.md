# auth (認証)

## 概要

匿名認証スタートの認証基盤 (documents/adr/0001-tech-stack.md)。登録なしで使い始められる。
Sign in with Apple / Google へのアカウントリンクは今後の実装。

## 画面

- `SignInResolver`: 画面ではなく resolver。子 Widget の表示前にサインイン済みであることを保証する
  - 未サインイン (初回起動) なら匿名サインインを実行し、完了までローディングを表示
  - サインイン失敗時はエラーメッセージをそのまま表示し、リトライボタンを出す

## フロー

1. アプリ起動 → `SignInResolver` が `FirebaseAuth.instance.currentUser` を確認
2. null なら `signInAnonymously()` を実行
3. `userChanges()` ストリームでサインイン完了を検知したら子 (MonthlyPage) を表示

## データ形式

- ユーザー ID は `currentUserIDProvider` (lib/provider/firebase_user.dart) で参照する
- Firestore のデータはすべて `/users/{userID}` 配下に置き、セキュリティルールで本人のみ許可する
  (firebase/firestore.rules、`.claude/rules/firestore-rules-simplicity.md`)

## 制約

- 匿名のまま端末を失うとデータも失われる。「機種変更に備えてバックアップ」導線 (アカウントリンク) を早期に出す方針 (ADR 0001)
