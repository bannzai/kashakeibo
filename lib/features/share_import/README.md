# share_import (共有 Extension からの取り込み)

## 概要

Safari のカード明細ページや写真アプリの共有シートから「カシャケイボ」を選ぶと、共有された画像が
アプリに渡り、撮影フロー (`features/capture`) の確認画面に合流して明細として登録できる機能 (issue #8)。
アプリを開いてから写真を選び直す手間をなくし、明細を見ているその場で記録できるようにする。

## 画面

専用の画面は持たない。取り込んだ画像はそのまま `features/capture` の `CapturePage`
(AI 解析中 → 読み取り確認 / 複数明細の候補リスト) を開く。
「取り直す」を選んだ場合はフォトライブラリを開き直す (共有元へは戻れないため)。

## フロー

1. Safari・写真アプリなどの共有シートでカシャケイボを選ぶ
2. 共有 Extension が受け取った画像を App Group コンテナの `shared-images/` へ保存し、URL スキームでホストアプリを開く
3. ホストアプリは月次一覧 (`features/monthly`) の表示開始時と foreground 復帰時に `useSharedImageImport` で取り込みを実行する
4. 取り込みは MethodChannel `takeSharedImages` で画像を取り出し (ネイティブ側は渡したファイルを削除する)、画像ごとに撮影フロー (アップロード → 解析 → 確認 → 登録) を順に開く
5. 一巡したら再度取り出しを行い、空になるまで繰り返す (確認画面の表示中に共有された画像も同じ導線で処理する)
6. 登録した明細の出所は `screenshot`。複数明細のスクショは候補リストで採用・破棄を選ぶ (`features/capture`)

## データ形式

- MethodChannel: `com.bannzai.kashakeibo/shared_image_inbox`
  - メソッド `takeSharedImages`: 引数なし。戻り値は `List<Map>` で、各要素は `imageBytes` (`Uint8List`) と `imageContentType` (`String`)
  - 取り出しは破壊的で、返した画像はネイティブ側で削除される (2 回目の呼び出しでは返らない)
- App Group: `group.<アプリの bundle ID>` (entitlements の `group.$(APP_BUNDLE_IDENTIFIER)`。dev / prod で別のコンテナ)。共有 Extension とホストアプリで共有するコンテナの `shared-images/` に、共有した順に取り出せる「時刻 + 連番」のファイル名で画像を保存する
- URL スキーム: `kashakeibo-share-<アプリの bundle ID>` (Runner の Info.plist `CFBundleURLTypes`)。共有 Extension がホストアプリを前面に出すためだけに使い、URL の中身は読まない (取り込みは受信箱の走査で行う)
- 画像形式: Worker が受け付ける JPEG / PNG / WebP / HEIC はそのまま、それ以外の形式と 10MB を超える画像は共有 Extension が JPEG に変換する
- iOS 側の実装: 受信箱の場所と ID の導出は `ios/Shared/SharedImageInboxLocation.swift` (両ターゲットで共有)、共有 Extension は `ios/ShareExtension/` (ターゲット `ShareExtension`、bundle ID `<アプリの bundle ID>.ShareExtension`、設定は `ios/Flutter/ShareExtension-*.xcconfig`)、ホストアプリ側の取り出しは `ios/Runner/SharedImageInbox.swift` (AppDelegate で MethodChannel を登録)

## 有効期限・制約

- iOS のみ。Android は共有 Extension を持たないため、`takeSharedImages` は他プラットフォームで常に空リストを返す
- 配布ビルドでは共有 Extension 用の App ID・provisioning profile と、Runner 側の App Groups capability が必要 (`.github/workflows/flutter-deploy.yml` の `IOS_SHARE_EXTENSION_*`)
- 共有 Extension は独自 UI を持たず、共有シートでアプリを選ぶとすぐホストアプリへ切り替わる。共有元のアプリへ自動では戻らない
- 取り込み中に foreground 復帰が起きても、実行中フラグにより同じ画像で確認画面が二重に開くことはない
- 共有画像は取り出した時点でネイティブ側から消えるため、取り込み後にアプリを終了しても App Group に残らない
