---
paths:
  - "lib/**/*.dart"
---

# Firestore タイムスタンプ更新ルール

Firestore のドキュメントには、クライアント端末の時刻に依存する `createdDateTime` / `updatedDateTime` とは別に、サーバー側のタイムスタンプ `serverCreatedDateTime`（新規作成時）/ `serverUpdatedDateTime`（作成時・更新時の両方）を持たせ、正確な時系列を把握できるようにする。

- Entity のフィールドに `lib/entity/timestamp.dart` の `@ServerCreatedTimestamp()` / `@ServerUpdatedTimestamp()` コンバータを付けて付与する（`toJson` で `FieldValue.serverTimestamp()` に変換される）。書き込み側で手動で `FieldValue.serverTimestamp()` を組み立てない
- 更新方式は `.claude/rules/firestore-fieldvalue-rules.md` の「`set` + `SetOptions(merge: true)` に統一する」に従う
