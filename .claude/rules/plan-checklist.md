# Plan ファイルチェックリスト

Plan mode でプランファイルを作成する際、以下のチェックリストを末尾に追記する。変更対象に無いセクションは省く。

---

## チェックリスト

### 実装内容
- [ ] 変更対象ファイルごとに具体的なコード提案をコードブロックで記載し、既存コードのパターン・構成に合わせている
- [ ] 新規・変更機能に対するテストが存在する（なければ新規作成）

### Flutter（lib/ に変更がある場合）
- [ ] AGENTS.md「ビルド・テスト・検証方法」の各コマンド（build_runner / analyze / test / iOS・Android ビルド）が通る
- [ ] `.claude/rules/coding-conventions.md`・`riverpod-rules.md`・`entity-parent-id-rules.md` の規約を満たしている

### Cloudflare Worker（workers/ に変更がある場合）
- [ ] worker ディレクトリで `npm run build`（または `tsc --noEmit`）と vitest が通る
- [ ] 認証: Firebase Auth の ID token 検証を経由しないエンドポイントを追加していない

### Firestore 設定（firestore.rules / インデックスに変更がある場合）
- [ ] セキュリティルールが `.claude/rules/firestore-rules-simplicity.md` の判定パターン内に収まっている
- [ ] クエリ用フィールドの複合インデックスが定義されている（`.claude/rules/firestore-aggregation-rules.md`）
