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

### Firebase（firebase/ に変更がある場合）
- [ ] Lint: `npm run lint` パス（firebase/functions/functions/ で実行）
- [ ] ビルド: `npm run build` 成功
- [ ] テスト: `npm test` 全件パス
- [ ] クライアント呼び出し関数はGenKitで定義
- [ ] onDocumentCreated/onDocumentUpdated トリガーを使っていない
- [ ] 新規・変更機能に対するテストが存在する（なければ新規作成）

### 共通
- [ ] エラーメッセージはそのまま表示（加工・プレフィックス除去なし）
