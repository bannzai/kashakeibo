---
paths:
  - "lib/**/*.dart"
---

# Riverpod 使用ルール

## 原則: build内で ref.watch → ローカル変数にキャプチャ → コールバックはその変数を使う

`ConsumerWidget` や `HookConsumerWidget` の `build` メソッド内でProviderを取得する場合は、状態Provider（`currentUserIDProvider` 等）・機能Provider（`call` メソッドを持つclass等）を問わず `ref.watch` を使い、ローカル変数に確保する。`onPressed` などのコールバック（クロージャ）内では、そのローカル変数を参照するだけにし、**コールバック内で新たに `ref.read` / `ref.watch` を呼ばない**。

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final addTransaction = ref.watch(addTransactionProvider); // OK: build で watch してキャプチャ
  ...
  onPressed: () async {
    final reviewed = await showSheet(...);
    await addTransaction.call(...); // unmount後も安全。ここで ref.read すると unmount 後は StateError
  }
}
```

理由: コールバック内で `ref.read` を呼ぶと、await後（widgetがunmountされ得るタイミング）に `ref` へ触れることになり、flutter_riverpodが `StateError('Cannot use "ref" after the widget was disposed.')` をthrowする（実例: shoppinglist #486 の写真から追加フローで StateError が握りつぶされ 1 件も追加されない）。build内で `ref.watch` してキャプチャした変数のみを使う構造にすれば、refへのアクセスは常にmount中に限定される。「コールバック内の `ref.read` を `ref.watch` に置換する」のではなく、構造変更が必要になる点に注意する。

参照:
- https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/WidgetRef/read.html （「AVOID calling read inside build」）
- https://riverpod.dev/docs/concepts2/consumers

## 注意点・例外

- **Notifierのライフサイクル**: `ref.watch(xxxProvider.notifier)` でキャプチャしたnotifierは、autoDisposeなProviderが破棄された後に使用すると例外になる。「誰かが watch し続けている」または `keepAlive` されていることが前提になる
- **長いawait中の値変化**: キャプチャした値はクロージャ生成時点のもの。await中（例: シート表示中）に値が変わっても追従しない。「操作時点の最新値」が必要なケースは設計時に意識する
- **family引数がコールバック内でしか決まらないケース**: build時に watch できないため個別対応する
