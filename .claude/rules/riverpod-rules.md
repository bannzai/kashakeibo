---
paths:
  - "lib/**/*.dart"
---

# Riverpod 使用ルール

## 原則: build内で ref.watch → ローカル変数にキャプチャ → コールバックはその変数を使う

`ConsumerWidget` や `HookConsumerWidget` の `build` メソッド内でProviderを取得する場合は、状態Provider（`currentUserIDProvider` 等）・機能Provider（`call` メソッドを持つclass等）を問わず `ref.watch` を使い、ローカル変数に確保する。`onPressed` などのコールバック（クロージャ）内では、そのローカル変数を参照するだけにし、**コールバック内で新たに `ref.read` / `ref.watch` を呼ばない**。

```dart
// NG: コールバック内で ref.read
onPressed: () async {
  final reviewed = await showSheet(...);
  await ref.read(addShoppingListItemProvider(groupID: groupID)).call(...); // unmount後だとStateError
}

// OK: build で watch してキャプチャ
Widget build(BuildContext context, WidgetRef ref) {
  final addShoppingListItem = ref.watch(addShoppingListItemProvider(groupID: groupID));
  ...
  onPressed: () async {
    final reviewed = await showSheet(...);
    await addShoppingListItem.call(...); // unmount後も安全
  }
}
```

「コールバック内の `ref.read` を `ref.watch` に置換する」のではない点に注意する。build外でのwatchはできないため、**「build で watch → 変数キャプチャ → コールバックで変数使用」への構造変更**が必要になる。

### 理由（#486 / #492）

コールバック内で `ref.read` を呼ぶと、await後（widgetがunmountされ得るタイミング）に `ref` へ触れることになり、flutter_riverpodが `StateError('Cannot use "ref" after the widget was disposed.')` をthrowする（`_assertNotDisposed` は `context.mounted` を見て無条件throwする）。build内で `ref.watch` してキャプチャした変数のみを使う構造にすれば、refへのアクセスは常にmount中（build中）に限定されるため、このバグクラス（#486: 写真から追加フローでunmount後にref.readしてStateErrorが握りつぶされ1件も追加されない）は構造的に発生しなくなる。

参照:
- https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/WidgetRef/read.html （「AVOID calling read inside build」）
- https://riverpod.dev/docs/concepts2/consumers

## 注意点・例外

- **Notifierのライフサイクル**: `ref.watch(xxxProvider.notifier)` でキャプチャしたnotifierは、autoDisposeなProviderが破棄された後に使用すると例外になる。「誰かが watch し続けている」または `keepAlive` されていることが前提になる
- **長いawait中の値変化**: キャプチャした値はクロージャ生成時点のもの。await中（例: シート表示中）に値が変わっても追従しない。「操作時点の最新値」が必要なケースは設計時に意識する
- **family引数がコールバック内でしか決まらないケース**: build時に watch できないため個別対応する
