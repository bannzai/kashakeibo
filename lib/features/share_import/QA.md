---
feature: share_import
verification: mobile-mcp
last_verified_commit: a98c098aa2c1140213505b0157402db95836624a
last_verified_at: 2026-08-20
---

# share_import QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/8 (スクショ取込: 共有 Extension)
- 関連: lib/features/share_import/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | iOS 共有 Extension から画像を受け取り、アプリ起動後に同じ確認フローへ入る | 共有シートへの表示 / 共有からの自動オープンと取込 / 起動時の取り込み |
| S2 | 取り出した画像は二重に取り込まれない | 取り出し済み画像の削除 |

## 1. 共有 Extension

- [x] **共有シートへの表示**: 写真アプリで画像を選び共有シートを開くと、アプリ一覧に「Kashakeibo」が表示される (画像以外の共有には表示されない)
  - 自動化: manual (Maestro で写真アプリの共有シートを操作して確認する)
- [x] **共有からの自動オープンと取込**: 共有シートで Kashakeibo を選ぶと、ホストアプリが自動で前面に開き (ステータスバーに「◀ 写真」)、共有した画像の解析が始まって確認フロー (明細なし画像は失敗画面) に合流する
  - 自動化: manual
- [x] **起動時の取り込み**: 受信箱に画像が残った状態でアプリを起動すると、月次一覧の表示開始時に取り込みが走り確認フローが開く
  - 自動化: manual
- [x] **取り出し済み画像の削除**: 取り込んだ画像は App Group の受信箱 (`shared-images/`) から削除され、2 回目の起動で同じ画像が再取り込みされない
  - 自動化: manual (受信箱ディレクトリを `xcrun simctl get_app_container <UDID> <bundleId> groups` のパスで直接確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-20 (PR #49)**

ローカル Simulator (kashakeibo-issue-8-iOS26.5) + Firebase Emulator + ローカル Worker で、写真アプリ → 共有シート → Kashakeibo 選択 → 自動オープン → 解析 → 失敗画面 (風景写真のため明細なし) までを Maestro + mobile-mcp で確認した。受信箱への保存・取り出し後の削除はコンテナのファイル実体 (`.../Shared/AppGroup/.../shared-images/`) で確認した。スクリーンショットと全記録は PR #49 body を参照: https://github.com/bannzai/kashakeibo/pull/49

- 共有シートに Kashakeibo: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/8c6e2cb2-d68b-4a6b-b1b6-bfa33c0cac89.png" width="240">
- 共有からの自動オープン (「◀ 写真」表示で取込フローに合流): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/c31f73fc-c3b3-4278-a2b6-668faaf493c7.png" width="240">
- 起動時の取り込み (受信箱の画像で確認フローが開く): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/c5aa2479-e2a7-46a8-bd32-3c5a3afc73a5.png" width="240">

</details>

## 未検証の範囲

- 実機 (TestFlight ビルド) での共有 Extension (配布 CI の署名・TestFlight アップロード成功までは確認済み: https://github.com/bannzai/kashakeibo/actions/runs/32362282189 )
- foreground 復帰時の取り込み (実装は起動時と同じ経路。widget テストでカバー済み)
- 複数枚を一度に共有した場合の順次取り込み (1 枚ずつの取り出しに変更後は widget テスト・ネイティブの単体確認のみ)
