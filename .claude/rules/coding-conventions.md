---
paths:
  - "lib/**/*.dart"
---

# コーディング規約

- Entity のフィールド名は省略せず、長くても実態がわかる名前をつける（例: `imageID` ではなく `sourceImageID`）
- Firestore の DB に対して変更（書き込み・更新・削除）を行う場合は、`call` メソッドを持った class を提供する Provider を用意し、その Provider 経由で操作すること（例: `AddTransaction`, `ExcludeTransactionFromAggregation` など）
- 関数の引数は原則 `{required}` でラベルが呼び出し元につくようにする
- コンストラクタの引数も nullable であっても `required` をつける。ただし timestamp 等のメタデータフィールドは除く
- エラーメッセージについては、基本的にそのまま表示する（`e.toString()` の加工・プレフィックス除去等はしない）
