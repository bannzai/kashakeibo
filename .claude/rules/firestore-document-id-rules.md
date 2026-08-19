---
paths:
  - "lib/**/*.dart"
---

# Firestore Document ID ルール

基本的には Firestore の自動生成 ID を使用する（1:N の通常のサブコレクション。例: `/users/{userID}/transactions/{id}`、`/users/{userID}/sourceImages/{id}`）。

## Composite ID

親ドキュメントと 1:1 の情報を、map ではなく collection/document として格納したい場合（シングルトンドキュメント等）にのみ使用する。ID だけで何のエンティティか・所属リソースが判別でき、collectionGroup query で ID の衝突を防げる。

- フォーマット: `{EntityName}_{parentCollectionName}_{parentDocID}[_{additionalCollectionName}_{additionalDocID}]`（EntityName は PascalCase。例: `UserPrivate_users_{userID}` — `/users/{userID}/privates/` 内のシングルトン）
- ID 生成ロジックはエンティティクラスの static メソッドに集約する

```dart
class UserPrivate {
  static String documentID({required String userID}) => 'UserPrivate_users_$userID';
}
```
