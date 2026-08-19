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
  - "**/*.cpp"
  - "**/*.dart"
---
# クラスより関数を優先する

- class, struct, enumを使わなくて済むなら使わない。関数で済むなら関数にする（例: static メソッドしか持たない `UserService` / `MathHelper` のようなクラスは関数にする）
- やむを得ない時にだけclassを使う（継承が必要、フレームワークが要求する等）
- primitiveな用途（JSONデコード、generics関数に渡す型定義など）にはstruct/enumを使う
