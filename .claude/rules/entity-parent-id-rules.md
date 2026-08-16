---
paths:
  - "lib/entity/**/*.dart"
---

# Entity 親IDルール

## ルール
Firestore のサブコレクションに保存される Entity は、親ドキュメントの ID をフィールドとして保持する。

## 理由
- Firestore のドキュメントパスからしか親 ID を取得できない場合、ドキュメント単体で扱う際に親情報が失われる
- Entity 単体で完結した情報を持つことで、UI やロジックでの取り回しが容易になる

## 例
`users/{userID}/transactions/{transactionID}` に保存される明細 Entity は `userID` フィールドを持つ。
