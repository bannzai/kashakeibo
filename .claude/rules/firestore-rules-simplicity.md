# Firestore Rules はシンプルに保つ

## 原則
Firestore Security Rules は **JWT (Firebase Auth) 本人認証 + リソース所有判定のみ** を行う。
それ以外のデータ内容に踏み込んだガード（プレミアム判定・期間判定・特定フィールドの diff チェック等）は実装しない。

## 許可される判定パターン
- `request.auth != null` (認証済みか)
- `request.auth.uid == <userID>` (本人か)

## 実装してはいけない判定
- Custom Claims に基づく機能ガード (`request.auth.token.isPremium == true` 等)
- `resource.data.createdDateTime >= request.time - duration.value(N, 'd')` のような期間判定
- `request.resource.data.diff(resource.data).changedKeys().hasAny([...])` のような特定フィールド変更ガード
- `getAfter()` / `get()` を多用したクロスドキュメント参照（必要最小限に）

## 理由
- Rules が複雑化すると `permission-denied` の根本原因切り分けに時間がかかり、E2E や手動検証のブロッカーになる
- プレミアム機能制限（スキャン無料枠等）はクライアント UI 側のガードで制御する。Rules で二重に防ぐ必要はない
- データは `users/{userID}` 配下に閉じており、本人以外がアクセスできない構造で十分

## 参照
- shoppinglist での運用実績: https://github.com/bannzai/shoppinglist の同名ルール（Issue #239 の permission-denied 切り分けの経緯から確立）
