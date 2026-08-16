---
paths:
  - "lib/**/*.dart"
---

# コーディング規約

- Entity のフィールド名は省略せず、長くても実態がわかる名前をつける（例: `imageID` ではなく `sourceImageID`）
- Firestore の DB に対して変更（書き込み・更新・削除）を行う場合は、`call` メソッドを持った class を提供する Provider を用意し、その Provider 経由で操作すること（例: `AddTransaction`, `ExcludeTransactionFromAggregation` など）
- 関数の引数は原則 `{required}` でラベルが呼び出し元につくようにする
- コンストラクタの引数も nullable であっても `required` をつける。ただし timestamp 等のメタデータフィールドは除く
- Provider の取得は状態・機能を問わず build 内で `ref.watch` しローカル変数にキャプチャし、コールバックはその変数を参照する（詳細: `.claude/rules/riverpod-rules.md`）
- エラーメッセージについては、基本的にそのまま表示する（`e.toString()` の加工・プレフィックス除去等はしない）
- Firestore のサブコレクションに保存される Entity は、親ドキュメントの ID をフィールドとして保持する（詳細: `.claude/rules/entity-parent-id-rules.md`）
