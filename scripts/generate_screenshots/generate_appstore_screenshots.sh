#!/usr/bin/env bash

# Flutter widget test で App Store スクリーンショットを生成し、fastlane 形式へ配置する。
# 引数なしで日本語・英語の全5枚を生成する。-l と -n で1言語・1ページに絞れる。

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
      printf 'Usage: %s [-l ja|en-US] [-n 1|2|3|4|5]\n' "$0"
      exit 0
      ;;
    :|?)
      printf 'Usage: %s [-l ja|en-US] [-n 1|2|3|4|5]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ "$requested_language" != "all" ]] && ! is_supported_language "$requested_language"; then
  printf '未対応の言語です: %s（対応: ja, en-US）\n' "$requested_language" >&2
  exit 2
fi
if [[ "$requested_page_number" != "0" ]] && ! is_supported_page_number "$requested_page_number"; then
  printf '未対応のページ番号です: %s（対応: 1〜5）\n' "$requested_page_number" >&2
  exit 2
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
generated_languages=("${SUPPORTED_LANGUAGES[@]}")
generated_page_numbers=("${SUPPORTED_PAGE_NUMBERS[@]}")
if [[ "$requested_language" != "all" ]]; then
  generated_languages=("$requested_language")
fi
if [[ "$requested_page_number" != "0" ]]; then
  generated_page_numbers=("$requested_page_number")
fi
for language in "${generated_languages[@]}"; do
  for page_number in "${generated_page_numbers[@]}"; do
    file_name="$(screenshot_file_name "$page_number")"
    generated_files+=("$ARTIFACTS_ROOT/$language/$file_name")
  done
done
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
