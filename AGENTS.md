# カシャケイボ (Kashakeibo)

スクショ・写真を撮ったら記録される家計簿アプリを開発しています。Web ページ上のクレカ・EC の明細、レシートから、AI (Gemini vision) が明細を作り出して家計簿として登録します。

企画・要件・MVP スコープは @documents/PROJECT.md、技術スタックの決定と理由は @documents/adr/0001-tech-stack.md を参照してください。

- Flutter のコード: @lib/ 。機能 (Feature) ごとにディレクトリを切り、実装の説明はコード上のコメントと `lib/features/{feature}/README.md` に書く
- コーディング規約・ルール: @.claude/rules/ に配置する。プロジェクト仕様書・ADR 等のドキュメントは @documents/ に配置する

## ビルド・テスト・検証方法

実装後は手動テスト前に必ず、以下のテストを実行する。該当するものがなければテストを新規作成する。作成・実行が難しい場合はユーザーに報告する。

- コード生成 (freezed / riverpod_generator): `dart run build_runner build` で生成ファイルを更新してから以下を実行する
- 静的解析: `flutter analyze`
- テスト実行: `flutter test`
- iOS ビルド: `flutter build ios --no-codesign`
- Android ビルド: `flutter build apk`
- シミュレータでの動作確認: `/ios-simulator` skill を起点に `/sim-manager` でプロジェクト固有シミュレータを起動し、`flutter run` する
- E2E: Maestro を導入したら `maestro test maestro/flows/` (`/flutter-maestro` skill)。導入までは上記の手動確認で代替する

## Plan 時に考慮すること

プランファイルには変更対象ファイルごとの具体的な実装コード (コードブロック) を含め、末尾に `.claude/rules/plan-checklist.md` のチェックリストを追記し、上記の検証方法で検証完了までを行う。

<!-- ai-review-config begin -->
<!--
このブロックは自動生成です。直接編集せず、テンプレートを更新してから再生成してください。
内容は AI コードレビュー時の挙動指示であり、コードベース自体への規約ではありません。
-->

## レビュー時の応答スタイル

- 応答は日本語で行う

## レビュー範囲外

以下は自動レビューで指摘しない (別の検出経路があるため):

- コンパイルエラー・型エラー (ローカル/CI のビルドで検出される)
- Lint/フォーマット違反 (リンター・フォーマッターで検出される)
<!-- ai-review-config end -->
