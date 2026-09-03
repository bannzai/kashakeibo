#!/usr/bin/env bash
# Google Play Developer API 用のサービスアカウントを kashakeibo-prod に作り、鍵 JSON を GitHub Actions secret PLAY_SA_JSON_BASE64 に登録する。
# 冪等で、既存のサービスアカウント・鍵ファイルがあれば再利用する。
#
# Play Console 側でこのサービスアカウントをユーザーとして招待し、リリース権限を付ける操作は Web UI でしか行えないため
# 本スクリプトの対象外で、最後に手順を表示する (android/README.md)。
#
# 使い方: bash scripts/android/create-play-service-account.sh [--skip-github]
# 前提: gcloud (kashakeibo-prod の IAM を編集できるアカウントでログイン済み)、gh (bannzai/kashakeibo の secret を書ける)
set -euo pipefail

cd "$(dirname "$0")/../.."

REPO=bannzai/kashakeibo
GCP_PROJECT=kashakeibo-prod
SA_NAME=googleplay-publisher
SA_EMAIL="$SA_NAME@$GCP_PROJECT.iam.gserviceaccount.com"
SECRET_DIR=${KASHAKEIBO_ANDROID_SECRET_DIR:-"$HOME/.config/kashakeibo/android"}
KEY_FILE="$SECRET_DIR/googleplay-service-account.json"

SKIP_GITHUB=0
for arg in "$@"; do
  case "$arg" in
    --skip-github) SKIP_GITHUB=1 ;;
    *) echo "Error: 不明な引数: $arg" >&2; exit 1 ;;
  esac
done

command -v gcloud > /dev/null || { echo "Error: gcloud が見つかりません" >&2; exit 1; }

# Play Developer API はサービスアカウントが属するプロジェクトで有効にしておく必要がある
gcloud services enable androidpublisher.googleapis.com --project "$GCP_PROJECT" > /dev/null

if gcloud iam service-accounts describe "$SA_EMAIL" --project "$GCP_PROJECT" > /dev/null 2>&1; then
  echo "サービスアカウントは作成済みです: $SA_EMAIL"
else
  gcloud iam service-accounts create "$SA_NAME" --project "$GCP_PROJECT" --display-name "Google Play publisher (flutter-deploy)" > /dev/null
  echo "サービスアカウントを作成しました: $SA_EMAIL"
fi

mkdir -p "$SECRET_DIR"
chmod 700 "$SECRET_DIR"
if [ -f "$KEY_FILE" ]; then
  echo "鍵 JSON は生成済みのため再利用します: $KEY_FILE"
else
  gcloud iam service-accounts keys create "$KEY_FILE" --iam-account "$SA_EMAIL" --project "$GCP_PROJECT" > /dev/null
  echo "鍵 JSON を生成しました: $KEY_FILE"
fi
chmod 600 "$KEY_FILE"

if [ "$SKIP_GITHUB" -eq 0 ]; then
  command -v gh > /dev/null || { echo "Error: gh が見つかりません" >&2; exit 1; }
  VALUE=$(base64 < "$KEY_FILE" | tr -d '\n')
  [ -n "$VALUE" ] || { echo "Error: $KEY_FILE が空のため secret を登録しません" >&2; exit 1; }
  printf '%s' "$VALUE" | gh secret set PLAY_SA_JSON_BASE64 -R "$REPO"
  echo "GitHub secret を登録しました: PLAY_SA_JSON_BASE64"
fi

cat <<EOF

完了。Play Console での招待 (Web UI のみ) を行ってください:
1. https://play.google.com/console/ → 「ユーザーと権限」→「新しいユーザーを招待」
2. メールアドレスに $SA_EMAIL を入力する
3. アプリの権限で kashakeibo (com.bannzai.kashakeibo) を追加し、「リリース」の「製品版リリースの管理」「テストトラックへのリリースの管理」と「アプリ情報」の閲覧を付与する
4. 招待後、反映まで数分〜数時間かかることがある
EOF
