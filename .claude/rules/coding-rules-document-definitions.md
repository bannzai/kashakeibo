---
paths:
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.swift"
  - "**/*.kt"
  - "**/*.rb"
  - "**/*.rs"
  - "**/*.java"
  - "**/*.c"
  - "**/*.cpp"
  - "**/*.h"
  - "**/*.dart"
---
# 定義にはdocumentコメントを書く

- 構造の定義（class, struct, enum, property）をした場合はdocumentコメントを書く
- 関数の定義をした場合はdocumentコメントを書く
- 書く内容は「これは何を表現しているものか」。コードを読めば分かる挙動は繰り返さない（`coding-rules-single-source-info.md` を参照）
