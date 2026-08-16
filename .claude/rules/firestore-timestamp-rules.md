---
paths:
  - "lib/**/*.dart"
---

# Firestore タイムスタンプ更新ルール

## サーバータイムスタンプ
Firestore のドキュメントを更新する際は、サーバー側のタイムスタンプフィールドを必ず付与する。

### フィールド一覧
| フィールド | 用途 | 付与タイミング |
|---|---|---|
| `serverCreatedDateTime` | サーバー側の作成日時 | ドキュメント新規作成時 |
| `serverUpdatedDateTime` | サーバー側の更新日時 | ドキュメント作成時・更新時の両方 |

### 理由
- クライアント側の `createdDateTime` / `updatedDateTime` はユーザー端末の時刻に依存する
- サーバータイムスタンプにより、正確な時系列の把握が可能になる

### 実装例（Flutter / Dart）

更新方式は `.claude/rules/firestore-fieldvalue-rules.md` の「`set` + `SetOptions(merge: true)` に統一する」に従う。

```dart
// 更新時: entity の変更と同じ set に serverTimestamp を含める
await docRef.set(
  {
    ...entity.toJson(),
    'updatedDateTime': FieldValue.serverTimestamp(),
    'serverUpdatedDateTime': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);
```
