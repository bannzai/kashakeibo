---
paths:
  - "lib/**/*.dart"
---

# Flutter Hooks 規約

`useEffect` は依存配列の選択が副作用の挙動を大きく変えるため、直前のコメントに **目的**（何をするための Effect か）と **依存配列の意図**（なぜその依存配列にしたのか。含めなかったものがあればその理由）を明記する。

```dart
// Firestoreからプロフィールデータが初回読み込みされた時にTextFieldへ反映する。
// displayNameController.textが空の場合のみ設定することで、ユーザーが入力中の値を上書きしない。
useEffect(() {
  ...
  return null;
}, [myProfile]);
```
