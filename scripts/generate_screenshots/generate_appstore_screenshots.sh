#!/usr/bin/env bash

# Flutter widget test で App Store スクリーンショットを生成し、fastlane 形式へ配置する。
# 引数なしで日本語・英語、iPhone・iPad の全画像を生成する。
# -l と -n で1言語・1ページに絞れる。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/appstore_screenshot_env.sh"

requested_language="all"
requested_page_number="0"

while getopts ':l:n:h' option; do
  case "$option" in
    l) requested_language="$OPTARG" ;;
    n) requested_page_number="$OPTARG" ;;
    h)
      printf 'Usage: %s [-l language] [-n positive-page-number]\n' "$0"
      exit 0
      ;;
    :|?)
      printf 'Usage: %s [-l language] [-n positive-page-number]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ "$requested_language" != "all" ]] && ! is_supported_language "$requested_language"; then
  printf '未対応の言語です: %s（対応: ja, en-US）\n' "$requested_language" >&2
  exit 2
fi
if [[ "$requested_page_number" != "0" ]] && ! [[ "$requested_page_number" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ページ番号は正の整数で指定してください: %s\n' "$requested_page_number" >&2
  exit 2
fi

selected_artifacts_root="$ARTIFACTS_ROOT"
if [[ "$requested_language" != "all" ]]; then
  selected_artifacts_root="$ARTIFACTS_ROOT/$requested_language"
fi
if [[ "$requested_page_number" == "0" ]]; then
  file_pattern='*.png'
else
  page_prefix="$(printf '%02d' "$requested_page_number")"
  file_pattern="${page_prefix}_*.png"
fi

# 同じ引数で再実行しても古い端末クラスの画像が残らないよう、対象生成物だけを初期化する。
if [[ -d "$selected_artifacts_root" ]]; then
  find "$selected_artifacts_root" -type f -name "$file_pattern" -delete
fi

cd "$PROJECT_ROOT"
flutter test \
  test/features/appstore_screenshot/appstore_screenshot_test.dart \
  --plain-name 'App Store assets を生成する' \
  --dart-define=GENERATE_APPSTORE_ASSETS=true \
  --dart-define=APPSTORE_ASSET_KIND=screenshots \
  --dart-define=APPSTORE_ASSET_LANGUAGE="$requested_language" \
  --dart-define=APPSTORE_SCREENSHOT_PAGE="$requested_page_number" \
  --dart-define=APPSTORE_SCREENSHOT_OUTPUT_ROOT="$ARTIFACTS_ROOT"

generated_files=()
while IFS= read -r generated_file; do
  generated_files+=("$generated_file")
done < <(find "$selected_artifacts_root" -type f -name "$file_pattern" -print | sort)
if [[ "${#generated_files[@]}" -eq 0 ]]; then
  printf '生成されたスクリーンショットが見つかりません: %s/%s\n' \
    "$selected_artifacts_root" "$file_pattern" >&2
  exit 1
fi
xcrun swift "$SCRIPT_DIR/strip_png_alpha.swift" "${generated_files[@]}"

organize_arguments=()
if [[ "$requested_language" != "all" ]]; then
  organize_arguments+=("-l" "$requested_language")
fi
if [[ "$requested_page_number" != "0" ]]; then
  organize_arguments+=("-n" "$requested_page_number")
fi
if [[ "${#organize_arguments[@]}" -eq 0 ]]; then
  "$SCRIPT_DIR/organize_screenshots.sh"
else
  "$SCRIPT_DIR/organize_screenshots.sh" "${organize_arguments[@]}"
fi
