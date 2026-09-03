#!/usr/bin/env bash
# Android の release 署名 (Google Play の upload key) を整備する。冪等で、既存の keystore を上書きしない。
#
# 1. upload keystore と key.properties を git 管理外のディレクトリ (KASHAKEIBO_ANDROID_SECRET_DIR。既定 ~/.config/kashakeibo/android) に用意する。
#    既にあれば再利用し、無い時は --gcp-backup 指定なら GCP Secret Manager のバックアップから復元、それも無ければ新規生成する。
#    Play に登録済みの upload key を別の鍵で上書きすると鍵の再設定まで CI のアップロードが拒否されるため、
#    GitHub secret に登録済みの状態での新規生成は --force-new-key が無い限り中断する
# 2. keystore の SHA-1 を kashakeibo-prod の Firebase Android アプリへ登録する (登録済みなら何もしない)。
#    Google サインイン provider が有効な Firebase プロジェクトでは、登録に伴い Android / Web の OAuth client が google-services.json に現れる。
#    Play App Signing を有効にすると配布 APK は Google 管理のアプリ署名鍵で再署名されるため、upload key の SHA-1 だけでは
#    Play からインストールしたアプリの Google サインインが署名不一致で失敗する。初回 AAB アップロード後に Play Console の
#    「アプリの署名」から取得したアプリ署名鍵の証明書 SHA-1 を --extra-sha1 で渡して同じ経路で登録する
# 3. google-services.json を取得し直して android/app/google-services.json (git 管理外) を更新する
# 4. GitHub Actions secret (ANDROID_KEYSTORE_JKS_BASE64 / ANDROID_KEY_PROPERTIES_BASE64 / GOOGLE_SERVICES_JSON_PROD_BASE64) を登録する。
#    キー名は env-secret-registry の正準名。flutter-deploy.yml の build-android が読む
# 5. --gcp-backup を付けた時だけ、keystore と key.properties を GCP Secret Manager (kashakeibo-prod) にバックアップする
#    (secret 名 googleplay-upload-keystore / googleplay-upload-keyproperties。既にあれば何もしない)
#
# 使い方: bash scripts/android/setup-release-signing.sh [--skip-firebase] [--skip-github] [--gcp-backup] [--force-new-key] [--extra-sha1 <SHA-1>]...
# 前提: keytool (JDK)、jq、firebase CLI (kashakeibo-prod を扱えるアカウントでログイン済み)、gh (bannzai/kashakeibo の secret を書ける)。--gcp-backup は gcloud
# パスワードは stdout に出さない。SHA-1 は Play Console や Firebase の確認に使うため表示する。
set -euo pipefail

cd "$(dirname "$0")/../.."

REPO=bannzai/kashakeibo
FIREBASE_PROJECT=kashakeibo-prod
PACKAGE_NAME=com.bannzai.kashakeibo
KEY_ALIAS=upload
SECRET_DIR=${KASHAKEIBO_ANDROID_SECRET_DIR:-"$HOME/.config/kashakeibo/android"}
KEYSTORE_FILE="$SECRET_DIR/upload-keystore.jks"
KEY_PROPERTIES_FILE="$SECRET_DIR/key.properties"
GOOGLE_SERVICES_JSON=android/app/google-services.json
GCP_KEYSTORE_SECRET=googleplay-upload-keystore
GCP_KEY_PROPERTIES_SECRET=googleplay-upload-keyproperties

SKIP_FIREBASE=0
SKIP_GITHUB=0
GCP_BACKUP=0
FORCE_NEW_KEY=0
EXTRA_SHA1S=()
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-firebase) SKIP_FIREBASE=1 ;;
    --skip-github) SKIP_GITHUB=1 ;;
    --gcp-backup) GCP_BACKUP=1 ;;
    --force-new-key) FORCE_NEW_KEY=1 ;;
    --extra-sha1)
      shift
      [ $# -gt 0 ] || { echo "Error: --extra-sha1 に値がありません" >&2; exit 1; }
      # Play Console / Firebase はコロン区切り・大文字で表示するため、比較・登録の形式 (コロン無し小文字) に正規化する
      EXTRA_SHA1=$(printf '%s' "$1" | tr -d ':' | tr 'A-F' 'a-f')
      [[ "$EXTRA_SHA1" =~ ^[0-9a-f]{40}$ ]] || { echo "Error: --extra-sha1 の値が 40 桁の hex ではありません: $1" >&2; exit 1; }
      EXTRA_SHA1S+=("$EXTRA_SHA1")
      ;;
    *) echo "Error: 不明な引数: $1" >&2; exit 1 ;;
  esac
  shift
done

for cmd in keytool jq; do
  command -v "$cmd" > /dev/null || { echo "Error: $cmd が見つかりません" >&2; exit 1; }
done

# 1. keystore と key.properties
# PKCS12 (JDK 9 以降の keytool の既定) は store と key で別のパスワードを持てないため同じ値を使う
mkdir -p "$SECRET_DIR"
chmod 700 "$SECRET_DIR"
# 復元できるバックアップがあるかだけを判定する (復元自体は set -e が効く本体側で行い、途中で失敗したら止める)
gcp_backup_exists() {
  [ "$GCP_BACKUP" -eq 1 ] || return 1
  command -v gcloud > /dev/null || { echo "Error: gcloud が見つかりません" >&2; exit 1; }
  gcloud secrets describe "$GCP_KEYSTORE_SECRET" --project "$FIREBASE_PROJECT" > /dev/null 2>&1
}
if [ -f "$KEYSTORE_FILE" ]; then
  echo "keystore は生成済みのため再利用します: $KEYSTORE_FILE"
elif gcp_backup_exists; then
  gcloud secrets versions access latest --secret "$GCP_KEYSTORE_SECRET" --project "$FIREBASE_PROJECT" > "$KEYSTORE_FILE"
  gcloud secrets versions access latest --secret "$GCP_KEY_PROPERTIES_SECRET" --project "$FIREBASE_PROJECT" > "$KEY_PROPERTIES_FILE"
  echo "GCP Secret Manager のバックアップから復元しました: $KEYSTORE_FILE"
else
  # Play に登録済みの upload key を別の鍵で上書きすると、Play Console での鍵の再設定が完了するまで CI のアップロードが拒否される。
  # secret が既にある = Play へ登録済みの鍵がある状態とみなし、意図しない再生成を止める
  if [ "$SKIP_GITHUB" -eq 0 ] && [ "$FORCE_NEW_KEY" -eq 0 ]; then
    command -v gh > /dev/null || { echo "Error: gh が見つかりません" >&2; exit 1; }
    # 一覧の取得自体に失敗した時に「未登録」と誤判定して鍵を作らないよう、取得と判定を分ける (取得失敗は set -e で止まる)
    REGISTERED_SECRETS=$(gh secret list -R "$REPO")
    if printf '%s\n' "$REGISTERED_SECRETS" | grep -q '^ANDROID_KEYSTORE_JKS_BASE64[[:space:]]'; then
      cat >&2 <<EOF
Error: ローカルに keystore が無いのに GitHub secret ANDROID_KEYSTORE_JKS_BASE64 は登録済みです。
Play に登録済みの upload key を別の鍵で上書きすると、鍵の再設定が済むまで CI のアップロードが拒否されます。
GCP Secret Manager にバックアップがあれば --gcp-backup を付けて復元してください。
意図的に鍵を作り直す時だけ --force-new-key を付けます。
EOF
      exit 1
    fi
  fi
  STORE_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
  [ ${#STORE_PASSWORD} -eq 32 ] || { echo "Error: パスワードの生成に失敗しました" >&2; exit 1; }
  keytool -genkeypair -v \
    -keystore "$KEYSTORE_FILE" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASSWORD" -keypass "$STORE_PASSWORD" \
    -dname "CN=kashakeibo upload key, O=bannzai" > /dev/null
  # storeFile は android/app/build.gradle.kts が android/app からの相対で解決する。CI は keystore を android/app/upload-keystore.jks へ復元する
  cat > "$KEY_PROPERTIES_FILE" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF
  echo "keystore を生成しました: $KEYSTORE_FILE"
fi
[ -f "$KEY_PROPERTIES_FILE" ] || { echo "Error: $KEY_PROPERTIES_FILE がありません。keystore のパスワードを復元できないため中断します" >&2; exit 1; }
chmod 600 "$KEYSTORE_FILE" "$KEY_PROPERTIES_FILE"
STORE_PASSWORD=$(sed -n 's/^storePassword=//p' "$KEY_PROPERTIES_FILE")
[ -n "$STORE_PASSWORD" ] || { echo "Error: $KEY_PROPERTIES_FILE の storePassword が空です" >&2; exit 1; }

SHA1=$(keytool -list -v -keystore "$KEYSTORE_FILE" -storepass "$STORE_PASSWORD" -alias "$KEY_ALIAS" | sed -n 's/^[[:space:]]*SHA1: //p' | tr -d ':' | tr 'A-F' 'a-f')
[ ${#SHA1} -eq 40 ] || { echo "Error: keystore から SHA-1 を取得できませんでした" >&2; exit 1; }
echo "upload key の SHA-1: $SHA1"
SHA1_LIST=("$SHA1")
if [ ${#EXTRA_SHA1S[@]} -gt 0 ]; then
  SHA1_LIST+=("${EXTRA_SHA1S[@]}")
  for sha in "${EXTRA_SHA1S[@]}"; do
    echo "追加で登録する SHA-1 (Play App Signing のアプリ署名鍵): $sha"
  done
fi

# 2. Firebase への SHA-1 登録と 3. google-services.json の再取得
GOOGLE_SERVICES_JSON_UPDATED=0
if [ "$SKIP_FIREBASE" -eq 0 ]; then
  command -v firebase > /dev/null || { echo "Error: firebase CLI が見つかりません" >&2; exit 1; }
  APP_ID=$(firebase apps:list ANDROID --project "$FIREBASE_PROJECT" --json | jq -r --arg pkg "$PACKAGE_NAME" '.result[] | select(.packageName == $pkg) | .appId')
  [ -n "$APP_ID" ] || { echo "Error: $FIREBASE_PROJECT に $PACKAGE_NAME の Android アプリがありません" >&2; exit 1; }
  # upload key とアプリ署名鍵 (--extra-sha1) の両方を登録する。Play App Signing の再署名後も
  # Google サインインの署名照合が通るのは、配布 APK を署名する鍵の SHA-1 が登録されている場合だけ
  REGISTERED_SHA1S=$(firebase apps:android:sha:list "$APP_ID" --project "$FIREBASE_PROJECT" --json)
  for sha in "${SHA1_LIST[@]}"; do
    if printf '%s' "$REGISTERED_SHA1S" | jq -e --arg sha "$sha" '.result[] | select(.shaHash == $sha)' > /dev/null; then
      echo "SHA-1 は $FIREBASE_PROJECT に登録済みです: $sha"
    else
      firebase apps:android:sha:create "$APP_ID" "$sha" --project "$FIREBASE_PROJECT" > /dev/null
      echo "SHA-1 を $FIREBASE_PROJECT の Android アプリ ($APP_ID) に登録しました: $sha"
    fi
  done

  # --out は既存ファイルがあると上書き確認を挟むため、毎回新しい一時ファイルへ書く
  FETCHED_JSON=$(mktemp -d)/google-services.json
  firebase apps:sdkconfig ANDROID "$APP_ID" --project "$FIREBASE_PROJECT" --out "$FETCHED_JSON" > /dev/null
  jq -e --arg pkg "$PACKAGE_NAME" '.client[] | select(.client_info.android_client_info.package_name == $pkg)' "$FETCHED_JSON" > /dev/null \
    || { echo "Error: 取得した google-services.json に $PACKAGE_NAME の client がありません" >&2; exit 1; }
  # cp はシンボリックリンクの先 (メイン checkout の git 管理外ファイル) を書き換える
  cp "$FETCHED_JSON" "$GOOGLE_SERVICES_JSON"
  echo "google-services.json を更新しました: $GOOGLE_SERVICES_JSON"
  # Google サインインに必要な Web OAuth client (client_type 3)。SHA-1 登録直後は反映に時間がかかることがある
  WEB_CLIENT_COUNT=$(jq --arg pkg "$PACKAGE_NAME" '[.client[] | select(.client_info.android_client_info.package_name == $pkg) | .oauth_client[]? | select(.client_type == 3)] | length' "$GOOGLE_SERVICES_JSON")
  if [ "$WEB_CLIENT_COUNT" -gt 0 ]; then
    GOOGLE_SERVICES_JSON_UPDATED=1
  else
    echo "Warning: google-services.json に Web OAuth client (client_type 3) がまだありません。Firebase console で Google サインイン provider が有効か確認し、しばらく待ってから再実行してください。GOOGLE_SERVICES_JSON_PROD_BASE64 の更新は見送ります" >&2
  fi
fi

# 4. GitHub Actions secret
set_github_secret() {
  local name=$1 file=$2 value
  value=$(base64 < "$file" | tr -d '\n')
  [ -n "$value" ] || { echo "Error: $file が空のため secret $name を登録しません" >&2; exit 1; }
  printf '%s' "$value" | gh secret set "$name" -R "$REPO"
  echo "GitHub secret を登録しました: $name"
}
if [ "$SKIP_GITHUB" -eq 0 ]; then
  command -v gh > /dev/null || { echo "Error: gh が見つかりません" >&2; exit 1; }
  set_github_secret ANDROID_KEYSTORE_JKS_BASE64 "$KEYSTORE_FILE"
  set_github_secret ANDROID_KEY_PROPERTIES_BASE64 "$KEY_PROPERTIES_FILE"
  if [ "$GOOGLE_SERVICES_JSON_UPDATED" -eq 1 ]; then
    set_github_secret GOOGLE_SERVICES_JSON_PROD_BASE64 "$GOOGLE_SERVICES_JSON"
  fi
fi

# 5. GCP Secret Manager へのバックアップ (opt-in)
backup_to_gcp() {
  local name=$1 file=$2
  if gcloud secrets describe "$name" --project "$FIREBASE_PROJECT" > /dev/null 2>&1; then
    echo "GCP Secret Manager にバックアップ済みです: $name"
  else
    gcloud secrets create "$name" --project "$FIREBASE_PROJECT" --replication-policy automatic --data-file "$file" > /dev/null
    echo "GCP Secret Manager にバックアップしました: $name ($FIREBASE_PROJECT)"
  fi
}
if [ "$GCP_BACKUP" -eq 1 ]; then
  command -v gcloud > /dev/null || { echo "Error: gcloud が見つかりません" >&2; exit 1; }
  backup_to_gcp "$GCP_KEYSTORE_SECRET" "$KEYSTORE_FILE"
  backup_to_gcp "$GCP_KEY_PROPERTIES_SECRET" "$KEY_PROPERTIES_FILE"
fi

cat <<EOF

完了。残りの手順は android/README.md を参照:
- Google Play Console でアプリ (package $PACKAGE_NAME) を作成し、Play App Signing の upload key として上の SHA-1 の keystore で署名した AAB を初回だけ手動でアップロードする
- 初回アップロード後に Play Console の「リリース > 設定 > アプリの署名」でアプリ署名鍵の証明書 SHA-1 を確認し、--extra-sha1 <SHA-1> を付けて本スクリプトを再実行する
- Play Developer API 用のサービスアカウントは scripts/android/create-play-service-account.sh で作る
EOF
