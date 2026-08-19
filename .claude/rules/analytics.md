---
paths:
  - "lib/features/**/*.dart"
  - "lib/**/components/*.dart"
---

# Analytics 規約

ユーザーの行動調査・不具合調査のため、ユーザーインタラクションのコールバック先頭で `analytics.logEvent` を呼び出す。

- name は 40 文字以内
- parameters にはスコープ内で自然に取得できる ID を含め、key は value と同じ変数名にする
- キャンセル・閉じるも記録する。TextField 系の onChanged は不要で onSubmitted は記録する
