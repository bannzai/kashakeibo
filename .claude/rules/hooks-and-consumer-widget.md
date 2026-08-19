---
paths:
  - "lib/**/*.dart"
---

# Hooks・Widget の状態管理ルール

## useState は Widget 内部で完結するローカル状態にのみ使う

`useState(initialData)` の `initialData` は `ValueNotifier` の生成時に 1 回だけ使われ、以降の build では無視される（`StatefulWidget` の `initState` 相当で、`didUpdateWidget` に相当するメカニズムはない）。

- 使ってよい: UI の表示切替フラグ、テキスト入力値、タブのインデックスなど、外部データソースに由来しない値。または、そのデータを Widget 内部でユーザー操作によって変更する必要がある場合（例: 選択中の ID、フォームの入力値）
- 使ってはいけない: 外部から流れてくるデータ（Provider の値、親から渡された引数、Stream の結果など）をそのまま `initialData` に渡すこと。一度しか読まれないため、以降の更新が反映されない「データの流れの切断」が起きる（例: 親が `ref.watch` した一覧を子に引数で渡し、子が `useState(items)` に入れると、追加後も画面に反映されない）

## 子 Widget でデータの最新性が必要なら子自身が ref.watch で購読する

引数経由で受け取って `useState` にコピーしない。引数で受け取ったデータをそのまま `build()` 内で使うだけなら問題ない（親の再ビルドのたびに最新値が渡される）。

## HookConsumerWidget と ConsumerWidget の選択

`build` 内で `useState`, `useEffect`, `useMemoized` などの hook 呼び出しが 1 つもなければ `ConsumerWidget` にする。`ConsumerWidget` であれば `useState` を誤用する余地自体がなくなる。
