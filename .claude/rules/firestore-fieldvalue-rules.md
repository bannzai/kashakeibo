---
paths:
  - "lib/**/*.dart"
---

# Firestore FieldValue ルール

## FieldValue.delete() を使用しない

Dart には `undefined` と `null` の区別がなく、DB の Entity も両者を区別しないように設計する。`FieldValue.delete()` を使うと `update` + マップリテラルによる更新が必要になり、`set` + `copyWith` と混在してコードが複雑になる。

- nullable フィールドの値を消したい場合は `null` をセットする（freezed 3.1.0 の `copyWith` は sentinel value パターンのため、`copyWith(field: null)` で明示的に `null` がセットされる）
- Firestore の更新は `set` + `copyWith` + `SetOptions(merge: true)` に統一する
