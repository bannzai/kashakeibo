# Plan ファイルチェックリスト

Plan mode で .plans/ にプランファイルを作成する際、以下のチェックリストをプランファイル末尾に追記すること。

## ルール
- 変更対象に応じて該当セクションのみ含める（Flutter変更なし → Flutterセクション省略）
- チェック項目は `- [ ]` 形式で記載
- プランには必ず変更対象ファイルごとに具体的な実装コード提案（コードブロック）を含めること

## チェックリストテンプレート

以下をプランファイル末尾に追記する。

---

## チェックリスト

### 実装内容
- [ ] 変更対象ファイルごとに具体的なコード提案をコードブロックで記載している
- [ ] 既存コードのパターン・構成を確認し、同じパターンで実装している

### Flutter（lib/ に変更がある場合）
- [ ] コード生成: `dart run build_runner build` で生成ファイル更新
- [ ] 静的解析: `flutter analyze` エラーなし
- [ ] テスト: `flutter test` 全件パス
- [ ] iOS ビルド: `flutter build ios` 成功
- [ ] Android ビルド: `flutter build apk` 成功
- [ ] 新規・変更機能に対するテストが存在する（なければ新規作成）
- [ ] Maestro E2E: 該当する maestro flow があれば実行、なければ新規作成
- [ ] Entity命名: フィールド名が省略されていない
- [ ] DB操作: Firestore操作は `call` クラスのProvider経由
- [ ] 引数: 関数・コンストラクタの引数に `{required}` あり（timestamp等メタデータ除く）
- [ ] ref使い分け: Providerはbuild内で`ref.watch`しローカル変数にキャプチャ、コールバック内で新たに`ref.read`/`ref.watch`を呼んでいない
- [ ] サブコレクションEntityに親ドキュメントIDフィールドあり（該当する場合）

### Cloudflare Worker（workers/ に変更がある場合）
- [ ] ビルド・型チェック: worker ディレクトリで `npm run build`（または `tsc --noEmit`）成功
- [ ] テスト: worker のテスト（vitest 等）全件パス
- [ ] 認証: Firebase Auth の ID token 検証を経由しないエンドポイントを追加していない
- [ ] 新規・変更機能に対するテストが存在する（なければ新規作成）

### Firestore 設定（firestore.rules / インデックスに変更がある場合）
- [ ] セキュリティルールが `.claude/rules/firestore-rules-simplicity.md` の判定パターン内に収まっている
- [ ] クエリ用フィールドの複合インデックスが定義されている（`.claude/rules/firestore-aggregation-rules.md`）

### 共通
- [ ] エラーメッセージはそのまま表示（加工・プレフィックス除去なし）
