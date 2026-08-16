---
paths:
  - "lib/**/*.dart"
---

# Firestore FieldValue ルール

## FieldValue.delete() を使用しない

DartクライアントからFirestoreのフィールドを削除する場合、`FieldValue.delete()` は使用しない。

### 理由

- Dartには `undefined` と `null` の区別がない（JavaScriptとは異なる）
- DBのEntityは `undefined` / `null` を区別しないように設計すべき
- `FieldValue.delete()` を使うと `update` + マップリテラルによる更新が必要になり、`set` + `copyWith` と混在してコードが複雑になる

### 方針

- nullableフィールドの値を消したい場合は `null` をセットする
- Firestoreの更新は `set` + `copyWith` + `SetOptions(merge: true)` に統一する
- freezed 3.1.0 の `copyWith` は sentinel value パターンを採用しているため、`copyWith(field: null)` で明示的に `null` がセットされる

### 例

```dart
// OK: null をセットして値を消す
docRef.set(
  entity.copyWith(
    color: null,
    description: null,
  ),
  SetOptions(merge: true),
);

// NG: FieldValue.delete() を使わない
docRef.update({
  'color': FieldValue.delete(),
  'description': FieldValue.delete(),
});
```
