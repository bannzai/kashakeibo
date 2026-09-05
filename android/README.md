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
- `--gcp-backup` を付けると kashakeibo-prod の GCP Secret Manager にも keystore と key.properties をバックアップする (secret 名 `googleplay-upload-keystore` / `googleplay-upload-keyproperties`)。ローカルに keystore が無い時は、このバックアップからの復元を新規生成より優先する
- ローカルに keystore が無く、かつ secret `ANDROID_KEYSTORE_JKS_BASE64` が登録済みの時は、Play に登録済みの upload key を上書きしないようスクリプトが中断する。`--gcp-backup` で復元するか、意図的に鍵を作り直す時だけ `--force-new-key` を付ける
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

4. **アプリ署名鍵の SHA-1 を Firebase に登録する**。Play App Signing では配布 APK が Google 管理のアプリ署名鍵で再署名されるため、upload key の SHA-1 だけでは Play からインストールしたアプリの Google サインインが署名不一致で失敗する。初回 AAB アップロード後に「リリース > 設定 > アプリの署名」の「アプリの署名鍵の証明書」から SHA-1 を取得して登録し、google-services.json と secret を更新する:

   ```sh
   bash scripts/android/setup-release-signing.sh --extra-sha1 <アプリ署名鍵の SHA-1>
   ```

### 3. Play Developer API 用サービスアカウント

```sh
bash scripts/android/create-play-service-account.sh
```

- kashakeibo-prod にサービスアカウント `googleplay-publisher` を作り、鍵 JSON を `~/.config/kashakeibo/android/googleplay-service-account.json` に保存して secret `PLAY_SA_JSON_BASE64` を登録する (冪等)
- その後、Play Console の「ユーザーと権限」からサービスアカウントのメールアドレスを招待し、kashakeibo の「テストトラックへのリリースの管理」と「アプリ情報の閲覧」を付与する。workflow のアップロード先は internal トラック固定のため、漏洩時の影響を CI に必要な範囲に限定する目的で「製品版リリースの管理」は付与しない (製品版への昇格は Play Console で人間が行う)。スクリプトが最後に手順を表示する

### 4. RevenueCat の Play Store app

RevenueCat 用のサービスアカウントは、必要な権限が CI 用と異なる (購入検証・entitlement 同期のための閲覧と注文管理) ため分けて作る:

```sh
bash scripts/android/create-play-service-account.sh --revenuecat
```

- kashakeibo-prod にサービスアカウント `googleplay-revenuecat` を作り、鍵 JSON を `~/.config/kashakeibo/android/googleplay-revenuecat-service-account.json` に保存する (冪等)。渡し先が Web UI のため GitHub secret には登録しない
- Play Console の「ユーザーと権限」でこのアカウントを招待し、「アプリ情報の閲覧」「財務データ、注文、解約アンケートの閲覧」「注文と定期購入の管理」を付与する
- RevenueCat の prod プロジェクトに Play Store app (`com.bannzai.kashakeibo`) を作り、この鍵 JSON を RevenueCat Dashboard の Play Store app 設定にアップロードする (アップロードは Web UI のみ。app・商品の作成は revenuecat-product-setup skill)

得られる public API key (`goog_...`) を secret `REVENUECAT_PUBLIC_API_KEY_ANDROID_PROD` に登録する:

```sh
printf '%s' "$KEY" | gh secret set REVENUECAT_PUBLIC_API_KEY_ANDROID_PROD -R bannzai/kashakeibo
```

### 5. 配布ワークフローの実行

secret が揃ったら、`flutter-deploy` を workflow_dispatch (platform = android) で起動して internal トラックへのアップロードを確認する。以降は main へのマージごとに iOS と一緒に自動配布される。production への昇格は Play Console で行う。

```sh
gh workflow run flutter-deploy -R bannzai/kashakeibo -f platform=android
```
