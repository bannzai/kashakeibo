---
paths:
  - "lib/**/*.dart"
---

# Firestore Document ID ルール

## 基本方針
基本的には Firestore の自動生成 ID を使用する。

通常のサブコレクション（例: `/users/{userID}/transactions/{id}`、`/users/{userID}/sourceImages/{id}`）では Firestore の自動生成 ID で十分。

## Composite ID
Composite ID は、特定のリレーションを明示する必要がある場合にのみ使用する。

### 使用するケース
- 親ドキュメントと 1:1 の情報を、map ではなく collection/document として格納したい場合（シングルトンドキュメント等）

### 使用しないケース
- 1:N の通常のサブコレクション（明細、画像等）
- 親のパス自体で親子関係が明確な場合

### フォーマット
```
{EntityName}_{parentCollectionName}_{parentDocID}[_{additionalCollectionName}_{additionalDocID}]
```

- `{EntityName}`: PascalCase のエンティティ名（先頭に来ることで ID の種類が一目で分かる）
- `{parentCollectionName}_{parentDocID}`: 親コレクション名とドキュメント ID のペア
- 複数キーが必要な場合は `_{collectionName}_{docID}` を連結

### 例
- `UserPrivate_users_{userID}` — `/users/{userID}/privates/` 内のシングルトン

### 理由
- エンティティ名が先頭にあるため、ID だけで何のエンティティか判別できる
- collectionGroup query で ID の衝突を防げる
- デバッグ時に ID から所属リソースを即座に判別できる

### 実装
Composite ID を使用する場合、エンティティクラスに static メソッドとして ID 生成ロジックを集約する。

```dart
class UserPrivate {
  static String documentID({required String userID}) => 'UserPrivate_users_$userID';
}
```
