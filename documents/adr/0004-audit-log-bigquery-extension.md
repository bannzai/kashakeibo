# 0004. 訂正削除履歴は Stream Firestore to BigQuery extension で記録する

- ステータス: 採用 ([ADR 0003](0003-denshi-choubo-hozon-hou-youken-jissou.md) の決定 1 (訂正削除履歴) の記録方式を置き換える。ADR 0003 のその他の決定 (タイムスタンプ・画質担保・検索・訴求は別判断) は維持)
- 日付: 2026-08-23
- 決定の経緯: https://github.com/bannzai/kashakeibo/pull/75 のレビューとオーナー判断 (issue #73 の実装過程での方針転換)

## 背景 (Context)

ADR 0003 の訂正削除履歴は、クライアントが `users/{userID}/auditLogs` サブコレクションへ履歴を書き込む方式で実装した。この方式には次の構造的な弱点があった。

1. **改ざん耐性がない**: 記録するのはクライアント自身のため、アプリの書き込みクラスを通らない SDK 直叩きは履歴に残らず、本人が SDK で履歴を書き換えることもできる (レビューでも指摘)
2. **横断的に使えない**: サブコレクションはユーザー横断の調査・分析・監査証跡の抽出に向かず、運用では結局 SQL が欲しくなる
3. **書き込みが倍増する**: 明細操作 1 回につき履歴 1 件を追加で書く

オーナー判断で「Cloud Functions / BigQuery / Eventarc がプロジェクトに増えることは許容する。SELECT 1 つで応用が効く形が良い」と方針が示され、サーバー側で変更を捕捉する方式へ転換した。

## 決定 (Decision)

**訂正削除履歴の正を、Firebase 公式 extension「Stream Firestore to BigQuery」(firebase/firestore-bigquery-export) が記録する BigQuery の changelog テーブルに置く。クライアントによる履歴書き込み (auditLogs サブコレクション) は撤去する。**

- extension は `users/{userId}/transactions` の全変更 (CREATE / UPDATE / DELETE、old_data 付き) を `firestore_export.transactions_raw_changelog` へストリームする。バージョンとパラメータは `firebase/firebase.json` + `firebase/extensions/firestore-bigquery-export.env` のマニフェストで管理し、dev / prod 両プロジェクトに `firebase deploy --only extensions` で適用する
- **導入はリリース前に行う**: changelog は extension 導入時点からしか始まらず、導入前の変更は遡って復元できないため
- **履歴画面の読み取り口は Worker** (`GET /audit-logs`): uid は検証済み ID token から強制し、無料プランの「直近 3 ヶ月」下限 ([ADR 0003] の全期間履歴プレミアム特典との整合) を**サーバー側で**適用する。BigQuery のクエリ課金 (1 クエリ最低 10MB) の乱用を防ぐため uid あたり日次回数制限を設ける。画像 (R2) の削除は、現行フローでは必ず明細ドキュメントの更新・削除を伴うため、changelog の UPDATE (sourceImageObjectKey の消失) / DELETE から導出する
- **アカウント削除時のパージは遅延実行** (`DELETE /audit-logs` + Worker の毎時 cron): 明細削除イベントの BigQuery への到着は非同期で、ストリーミングバッファ中の行は DML で削除できない (最大 90 分程度) ため、削除依頼を KV に登録し cron が uid の全行を DML で消えるまでリトライする。これに伴い docs/AccountDeletion.md の削除の同時性を「操作履歴は削除操作から数時間以内に完全に削除」へ改訂する (オーナー承認済み)

## 影響 (Consequences)

- **改ざん耐性**: 記録はサーバー側 (extension の Cloud Functions) で捕捉され、クライアントは迂回も書き換えもできない。ADR 0003 が記録していた「本人がクライアント SDK で書き換え可能」という制約は解消する。BigQuery 側の削除権限はパージ用サービスアカウント (Worker の secret) に限られる
- **ADR 0001 の「Cloud Functions ゼロ」の緩和**: extension が管理する Cloud Functions がプロジェクトに増える。手書きの Cloud Functions は引き続き持たず、自作サーバーコードは Worker に一本化する方針は変えない
- **Firestore の書き込み倍増が解消**: 明細操作は元の書き込み量に戻る
- **リアルタイム性の低下**: 履歴画面は snapshot listener ではなく API 取得 (プルリフレッシュ) になり、変更が反映されるまで extension のストリーム分の遅延 (秒オーダー) がある
- **コスト**: 10 万 MAU 規模でも extension (Functions 起動 + streaming insert + ストレージ) は月数ドル、履歴画面のクエリは日次制限とクラスタリング (document_name)・日次パーティションで抑制する
- 「電帳法対応」を訴求するかの判断と、その時のサーバー側強制の再評価は引き続き ADR 0003 に従う
