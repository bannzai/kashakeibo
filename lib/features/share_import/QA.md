---
feature: share_import
verification: mobile-mcp
last_verified_commit: f492e1566dfd2fae08cfc3a15b79e1cc469e1e1e
last_verified_at: 2026-08-22
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
| S3 | 複数枚を一度に共有しても 1 枚ずつ順番に取り込まれ、全枚数が処理される (TakeNextSharedImage による 1 枚ずつの取り出し) | 複数枚共有の順次取り込み |

## 1. 共有 Extension

- [x] **共有シートへの表示**: 写真アプリで画像を選び共有シートを開くと、アプリ一覧に「Kashakeibo」が表示される (画像以外の共有には表示されない)
  - 自動化: manual (Maestro で写真アプリの共有シートを操作して確認する)
- [x] **共有からの自動オープンと取込**: 共有シートで Kashakeibo を選ぶと、ホストアプリが自動で前面に開き (ステータスバーに「◀ 写真」)、共有した画像の解析が始まって確認フロー (明細なし画像は失敗画面) に合流する
  - 自動化: manual
- [x] **起動時の取り込み**: 受信箱に画像が残った状態でアプリを起動すると、月次一覧の表示開始時に取り込みが走り確認フローが開く
  - 自動化: manual
- [x] **取り出し済み画像の削除**: 取り込んだ画像は App Group の受信箱 (`shared-images/`) から削除され、2 回目の起動で同じ画像が再取り込みされない
  - 自動化: manual (受信箱ディレクトリを `xcrun simctl get_app_container <UDID> <bundleId> groups` のパスで直接確認する)
- [x] **複数枚共有の順次取り込み**: 写真アプリで 2 枚以上を選んで共有すると、1 枚ずつ順番に確認フローが開き、全枚数が取り込まれる (受信箱が空になる)
  - 自動化: manual (Maestro で写真アプリの複数選択・共有シートを操作して確認する)
  - 受信箱を直接作り込む手順: アプリを終了した状態で App Group の `shared-images/` へ画像ファイルを置くと、共有 Extension が保存した状態と同じになる。ネイティブ側 (ios/Runner/SharedImageInbox.swift) はファイル名の昇順で最も古い 1 枚を取り出して削除するため、`1-xxx.png` / `2-yyy.jpg` のように順序が分かる名前にすると取り込み順を確認できる。Content-Type は拡張子から決まる
- [ ] **取り出し失敗時の再試行**: 受信箱からの取り出しに失敗した画像は受信箱に残り、次回の起動・foreground 復帰で再試行される
  - 自動化: todo (取り出し失敗を Simulator 上で作り込む手段が未整備。widget テスト test/features/share_import/shared_image_import_test.dart でカバー済み)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-20 (PR #49)**

ローカル Simulator (kashakeibo-issue-8-iOS26.5) + Firebase Emulator + ローカル Worker で、写真アプリ → 共有シート → Kashakeibo 選択 → 自動オープン → 解析 → 失敗画面 (風景写真のため明細なし) までを Maestro + mobile-mcp で確認した。受信箱への保存・取り出し後の削除はコンテナのファイル実体 (`.../Shared/AppGroup/.../shared-images/`) で確認した。スクリーンショットと全記録は PR #49 body を参照: https://github.com/bannzai/kashakeibo/pull/49

- 共有シートに Kashakeibo: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/8c6e2cb2-d68b-4a6b-b1b6-bfa33c0cac89.png" width="240">
- 共有からの自動オープン (「◀ 写真」表示で取込フローに合流): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/c31f73fc-c3b3-4278-a2b6-668faaf493c7.png" width="240">
- 起動時の取り込み (受信箱の画像で確認フローが開く): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/c5aa2479-e2a7-46a8-bd32-3c5a3afc73a5.png" width="240">

### **共有シートへの表示**: 写真アプリで画像を選び共有シートを開くと、アプリ一覧に「Kashakeibo」が表示される (画像以外の共有には表示されない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (kashakeibo-無名-iOS26.5 / UDID 3DAA814A-102E-4D40-A0DD-676959F17E48、日本語ロケール)、debug ビルド (kashakeibo-dev + dev Worker)。写真アプリで「選択」から風景写真 2 枚を選び (左)、共有ボタンを押すと共有シートの上段アプリ一覧に「Kashakeibo」が並んだ (右。見出しは「2 Photos Selected」)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/cc9884e7-808e-49c3-a562-09f8328ab217.png" width="320" alt="写真アプリで2枚の写真を選択中">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b451764a-0cb8-4326-8c1f-7292a0d5d2a2.png" width="320" alt="共有シートのアプリ一覧にKashakeiboが表示">

</details>

### **共有からの自動オープンと取込**: 共有シートで Kashakeibo を選ぶと、ホストアプリが自動で前面に開き (ステータスバーに「◀ 写真」)、共有した画像の解析が始まって確認フロー (明細なし画像は失敗画面) に合流する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

共有シートで Kashakeibo を選ぶと、ホストアプリが自動で前面に開き (左上のステータスバーが「◀ 写真」)、「AI が読み取っています / カテゴリを推定しています」の解析画面に合流した。共有したのが風景写真のため、解析後は「読み取れませんでした」画面になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/940cd0b0-f47c-45c4-8b05-93424053e487.png" width="320" alt="共有から自動で開いた解析中画面。ステータスバーに◀写真">

</details>

### **起動時の取り込み**: 受信箱に画像が残った状態でアプリを起動すると、月次一覧の表示開始時に取り込みが走り確認フローが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

アプリを終了した状態で受信箱 (`.../Shared/AppGroup/<ID>/shared-images/`) にレシート画像 `1-receipt.png` と風景写真 `2-landscape.jpg` の 2 枚を置き、`xcrun simctl launch` で起動した。月次一覧の表示開始と同時に取り込みが走り、1 枚目 (レシート) の確認フローが開いて「サンプルストア 三軒茶屋店 / ¥1753 / 食費 / 2026年8月21日」が読み取られた状態のフォームが表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b8c05de3-876a-454f-a091-fbf4dbf02e75.png" width="320" alt="起動時に受信箱のレシートが取り込まれ読み取り確認画面が開いた状態">

</details>

### **取り出し済み画像の削除**: 取り込んだ画像は App Group の受信箱 (`shared-images/`) から削除され、2 回目の起動で同じ画像が再取り込みされない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

受信箱に 2 枚 (`1-receipt.png` / `2-landscape.jpg`) を置いて起動した後、1 枚目の確認フローが開いた時点で受信箱を `ls` すると `1-receipt.png` だけが消えて `2-landscape.jpg` が残っていた (取り出した 1 枚だけを削除している)。2 枚とも処理し終えた時点で受信箱は空になった。

```text
$ ls .../shared-images/   # 起動前
1-receipt.png  2-landscape.jpg
$ ls .../shared-images/   # 1 枚目の取り込み後
2-landscape.jpg
$ ls .../shared-images/   # 2 枚目の取り込み後
(空)
```

その後アプリを終了して再起動すると、確認フローは開かず月次一覧がそのまま表示され、同じ画像が再取り込みされないことを確認した (登録済みのサンプルストア 三軒茶屋店 ¥1,753 が一覧にあるだけで、新しい取り込みは発生していない)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b75c662e-ea3e-4079-b77a-59cb20eb1538.png" width="320" alt="再起動後の月次一覧。取り込みフローは開かない">

</details>

### **複数枚共有の順次取り込み**: 写真アプリで 2 枚以上を選んで共有すると、1 枚ずつ順番に確認フローが開き、全枚数が取り込まれる (受信箱が空になる)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

2 通りで確認した。

1. 写真アプリから風景写真 2 枚を選んで共有 → 1 枚目の解析 → 失敗画面を閉じると 2 枚目の解析 → 失敗画面、と順番に確認フローが開いた。残量チップが 48 回 → 46 回と 2 減っており、2 枚とも解析まで到達している (どちらも風景写真で失敗画面が同じ見た目のため、枚数の根拠は残量の減り方で判定した)
2. 見た目で 1 枚目・2 枚目を区別するため、受信箱にレシート `1-receipt.png` と風景写真 `2-landscape.jpg` を置いて起動した。1 枚目はレシートの読み取り確認フォーム (左)、そこで「登録する」を押すと続けて 2 枚目 (風景写真) の解析が走り「読み取れませんでした」画面が開いた (右)。処理後の受信箱は空。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b8c05de3-876a-454f-a091-fbf4dbf02e75.png" width="320" alt="1枚目のレシートの読み取り確認画面">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/5648d815-3c94-40e0-a0e7-401107dc61b3.png" width="320" alt="続けて開いた2枚目の読み取れませんでした画面">

</details>

### **取り出し失敗時の再試行**: 受信箱からの取り出しに失敗した画像は受信箱に残り、次回の起動・foreground 復帰で再試行される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

## 未検証の範囲

- 実機 (TestFlight ビルド) での共有 Extension (配布 CI の署名・TestFlight アップロード成功までは確認済み: https://github.com/bannzai/kashakeibo/actions/runs/32362282189 )
- foreground 復帰時の取り込み (実装は起動時と同じ経路。widget テストでカバー済み)
