# Android の配布 (Google Play)

配布ワークフロー `.github/workflows/flutter-deploy.yml` の `build-android` が、release keystore で署名した AAB をビルドして Google Play の internal トラックへアップロードする。本ドキュメントは、そのために git 管理外で用意するもの (keystore・Play Console・secret) と手順をまとめる (issue: https://github.com/bannzai/kashakeibo/issues/38 )。

## 署名の設計

- `android/app/build.gradle.kts` は `android/key.properties` があれば release 署名、無ければ debug 署名にフォールバックする。ローカルの `flutter run --release` / `flutter build apk` は key.properties 無しで従来どおり動く
- keystore は Play App Signing の **upload key** として使う。アプリ署名鍵は Google が管理するため、upload key を失っても Play Console から再設定できる (ただし手間がかかるので、生成した keystore は `~/.config/kashakeibo/android/` に置いたまま消さない)
- CI は secret から `android/key.properties` と `android/app/upload-keystore.jks` を復元してビルドし、ジョブの最後に削除する

## 用意する secret (GitHub Actions、リポジトリ bannzai/kashakeibo)

キー名は env-secret-registry の正準名。`check-android-secrets` ジョブは次の 4 つがすべて登録されるまで `build-android` を warning 付きで skip する (iOS の配布を止めないため)。揃った後に値が壊れている場合は `build-android` が fail する。

| secret | 内容 | 用意する手段 |
| --- | --- | --- |
| `ANDROID_KEYSTORE_JKS_BASE64` | upload keystore (`upload-keystore.jks`) の base64 | `scripts/android/setup-release-signing.sh` |
| `ANDROID_KEY_PROPERTIES_BASE64` | `key.properties` (storePassword / keyPassword / keyAlias / storeFile) の base64 | 同上 |
| `PLAY_SA_JSON_BASE64` | Play Developer API 用サービスアカウントの鍵 JSON の base64 | `scripts/android/create-play-service-account.sh` + Play Console での招待 |
| `REVENUECAT_PUBLIC_API_KEY_ANDROID_PROD` | RevenueCat prod プロジェクトの Play Store 用 public API key (`goog_...`) | RevenueCat に Play Store app を作る (revenuecat-product-setup skill。Play のサービスアカウント JSON が必要) |

`build-android` はこのほかに登録済みの `GOOGLE_SERVICES_JSON_PROD_BASE64` (kashakeibo-prod の google-services.json) と `SLACK_BOT_TOKEN` を読む。google-services.json は release keystore の SHA-1 を Firebase に登録した後に取得し直したもの (Web OAuth client を含む) でないと、Google サインインが動かない AAB になるため、ジョブがビルド前に検査して落とす。

## 手順

### 1. upload keystore の生成・Firebase への SHA-1 登録・secret 登録

```sh
bash scripts/android/setup-release-signing.sh
```

- keystore と key.properties を `~/.config/kashakeibo/android/` (環境変数 `KASHAKEIBO_ANDROID_SECRET_DIR` で変更可) に生成する。2 回目以降は既存の keystore を再利用する (冪等)
- SHA-1 を kashakeibo-prod の Firebase Android アプリ (`com.bannzai.kashakeibo`) に登録し、google-services.json を取得し直して `android/app/google-services.json` と secret `GOOGLE_SERVICES_JSON_PROD_BASE64` を更新する
- `ANDROID_KEYSTORE_JKS_BASE64` / `ANDROID_KEY_PROPERTIES_BASE64` を登録する
- `--gcp-backup` を付けると kashakeibo-prod の GCP Secret Manager にも keystore と key.properties をバックアップする (secret 名 `googleplay-upload-keystore` / `googleplay-upload-keyproperties`)
- 一部だけ実行したい時は `--skip-firebase` / `--skip-github`

### 2. Google Play Console でアプリを作成する (Web UI のみ)

1. Google Play Developer アカウント (登録料 $25、未登録なら) で https://play.google.com/console/ を開き、「アプリを作成」でパッケージ名 `com.bannzai.kashakeibo` のアプリを作る
2. 「リリース > 設定 > アプリの署名」で Play App Signing を有効にする (新規アプリは既定で有効)
3. **初回だけ AAB を手動でアップロードする**。Play Developer API はアプリが Play Console に存在し、一度でも AAB がアップロードされていないと `packageName` を解決できず、CI からの初回アップロードが失敗する。ローカルで release 署名の AAB を作る:

   ```sh
   cp ~/.config/kashakeibo/android/key.properties android/key.properties
   cp ~/.config/kashakeibo/android/upload-keystore.jks android/app/upload-keystore.jks
   flutter build appbundle --release --dart-define=REVENUECAT_PUBLIC_API_KEY_ANDROID=<goog_ のキー>
   # build/app/outputs/bundle/release/app-release.aab を「テスト > 内部テスト」の新しいリリースにアップロードする
   ```

   検証後は `android/key.properties` と `android/app/upload-keystore.jks` を消す (gitignore 済みだが、作業ツリーに置いたままにしない)

### 3. Play Developer API 用サービスアカウント

```sh
bash scripts/android/create-play-service-account.sh
```

- kashakeibo-prod にサービスアカウント `googleplay-publisher` を作り、鍵 JSON を `~/.config/kashakeibo/android/googleplay-service-account.json` に保存して secret `PLAY_SA_JSON_BASE64` を登録する (冪等)
- その後、Play Console の「ユーザーと権限」からサービスアカウントのメールアドレスを招待し、kashakeibo のリリース権限 (製品版・テストトラックのリリース管理) を付与する。スクリプトが最後に手順を表示する

### 4. RevenueCat の Play Store app

RevenueCat の prod プロジェクトに Play Store app (`com.bannzai.kashakeibo`) を作り、手順 3 のサービスアカウント JSON を登録する (revenuecat-product-setup skill)。得られる public API key (`goog_...`) を secret `REVENUECAT_PUBLIC_API_KEY_ANDROID_PROD` に登録する:

```sh
printf '%s' "$KEY" | gh secret set REVENUECAT_PUBLIC_API_KEY_ANDROID_PROD -R bannzai/kashakeibo
```

### 5. 配布ワークフローの実行

secret が揃ったら、`flutter-deploy` を workflow_dispatch (platform = android) で起動して internal トラックへのアップロードを確認する。以降は main へのマージごとに iOS と一緒に自動配布される。production への昇格は Play Console で行う。

```sh
gh workflow run flutter-deploy -R bannzai/kashakeibo -f platform=android
```
