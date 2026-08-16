---
paths:
  - "lib/**/*.dart"
---

# Flutter Hooks 規約

## useEffect のコメント
`useEffect` を使用する際は、その直前に以下を明記するコメントを追加する:
1. **目的**: 何をするためのEffectか
2. **依存配列の意図**: なぜその依存配列にしたのか（特に、含めなかったものがある場合はその理由）

### 例
```dart
// Firestoreからプロフィールデータが初回読み込みされた時にTextFieldへ反映する。
// displayNameController.textが空の場合のみ設定することで、ユーザーが入力中の値を上書きしない。
useEffect(() {
  if (myProfile != null && displayNameController.text.isEmpty) {
    displayNameController.text = myProfile.displayName ?? '';
  }
  return null;
}, [myProfile]);
```

### 理由
- `useEffect` は依存配列の選択が副作用の挙動を大きく変える
- 意図が不明確だとレビュー時に「なぜこの依存配列？」という疑問が生じる
- コメントがあることで、将来の修正時に依存配列を安易に変更してしまうリスクを防げる
