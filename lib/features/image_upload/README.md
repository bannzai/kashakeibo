# image_upload

## 概要

レシート・スクショ画像を Cloudflare Worker (`workers/image`) 経由で R2 にアップロード・取得・削除する機能。
Worker の API 仕様・認可設計 (uid 配下へのキー強制・未認証拒否) は `workers/image/README.md` を SSOT とする。
Firebase ID token の取得と HTTP クライアントの用意を含めた呼び出し口は `lib/provider/image.dart` の Provider 群
(`uploadCapturedImageProvider` / `fetchStoredImageProvider` / `deleteStoredImageProvider` 等) が担う。

## 画面

この feature に画面はない (HTTP クライアントのみ)。撮影フロー (`features/capture`)、明細詳細 (`features/transaction_detail`)、
スクショ取込 (issue #8) から利用される。

## フロー

1. 呼び出し側が Firebase Auth (issue #3) から ID token を取得し、論理アップロードごとに一意な UUID (`uploadImageID`) を生成する。通信エラー等の再試行では同じ UUID を使う (Worker が同じキーに上書きするため孤児画像が残らない)
2. `uploadImage` に画像バイト列・Content-Type・`uploadImageID`・ID token を渡すと、オブジェクトキー (`users/{uid}/{uploadImageID}.{拡張子}`) が返る
3. 返ったキーを Firestore の明細ドキュメントの `sourceImageObjectKey` に保存して画像と明細を紐づける (`features/capture`)
4. 表示時は `fetchImage` にキーと ID token を渡してバイト列を取得し、`Image.memory` で表示する (Worker は Authorization ヘッダー必須のため `Image.network` は使えない)
5. 明細から画像だけを外す・明細ごと削除する時は `deleteImage` でキーの画像 1 件を削除する (対象が無くても成功する。`features/transaction_detail`)
6. アカウント削除時は、Firebase Auth ユーザーを削除する前に `deleteAllImages` を呼んで本人の全画像を消去する

## データ形式

- 対応画像形式・サイズ上限は Worker 側 (`workers/image/src/handler.ts`) が検証する
- Firestore に保存するのはオブジェクトキー (URL ではない)。配信ドメインはデプロイ時に決まるため、URL は `{IMAGE_API_BASE_URL}/images/{キー}` としてクライアントで組み立てる

## 有効期限・制約

- ベース URL は `--dart-define=IMAGE_API_BASE_URL=https://...` で注入する。デプロイ済みの Worker は dev `https://kashakeibo-image-worker-dev.star-kojiki.workers.dev` / prod `https://kashakeibo-image-worker-prod.star-kojiki.workers.dev` (配布 CI `.github/workflows/flutter-deploy.yml` は prod を渡す)。未指定 (空文字) のビルドでは画像 API の呼び出しが失敗する
- Firebase ID token は最長1時間で失効するため、呼び出しの都度 Firebase Auth から最新の token を取得して渡す
