# image_upload

## 概要

レシート・スクショ画像を Cloudflare Worker (`workers/image`) 経由で R2 にアップロード・取得する機能。
Worker の API 仕様・認可設計 (uid 配下へのキー強制・未認証拒否) は `workers/image/README.md` を SSOT とする。

## 画面

この feature に画面はない (HTTP クライアントのみ)。撮影・取込フロー (issue #7, #8) や明細詳細 (issue #9) から利用される。

## フロー

1. 呼び出し側が Firebase Auth (issue #3) から ID token を取得する
2. `uploadImage` に画像バイト列・Content-Type・ID token を渡すと、Worker が採番したオブジェクトキー (`users/{uid}/{UUID}.{拡張子}`) が返る
3. 返ったキーを Firestore の明細ドキュメントに保存して画像と明細を紐づける (紐付けの実装は issue #9)
4. 表示時は `fetchImage` にキーと ID token を渡してバイト列を取得し、`Image.memory` で表示する (Worker は Authorization ヘッダー必須のため `Image.network` は使えない)

## データ形式

- 対応画像形式・サイズ上限は Worker 側 (`workers/image/src/handler.ts`) が検証する
- Firestore に保存するのはオブジェクトキー (URL ではない)。配信ドメインはデプロイ時に決まるため、URL は `{IMAGE_API_BASE_URL}/images/{キー}` としてクライアントで組み立てる

## 有効期限・制約

- ベース URL は `--dart-define=IMAGE_API_BASE_URL=https://...` で注入する (Worker デプロイ後に確定)
- Firebase ID token は最長1時間で失効するため、呼び出しの都度 Firebase Auth から最新の token を取得して渡す
