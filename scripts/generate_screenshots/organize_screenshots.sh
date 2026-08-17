#!/usr/bin/env bash

# artifacts に生成された PNG を fastlane/screenshots/{lang}/ へ配置する。
# 使用例: ./scripts/generate_screenshots/organize_screenshots.sh -l ja -n 1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/appstore_screenshot_env.sh"

requested_language="all"
requested_page_number="all"

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
if [[ "$requested_page_number" != "all" ]] && ! is_supported_page_number "$requested_page_number"; then
  printf '未対応のページ番号です: %s（対応: 1〜5）\n' "$requested_page_number" >&2
  exit 2
fi

languages=("${SUPPORTED_LANGUAGES[@]}")
page_numbers=("${SUPPORTED_PAGE_NUMBERS[@]}")
if [[ "$requested_language" != "all" ]]; then
  languages=("$requested_language")
fi
if [[ "$requested_page_number" != "all" ]]; then
  page_numbers=("$requested_page_number")
fi

for language in "${languages[@]}"; do
  mkdir -p "$FASTLANE_SCREENSHOTS_ROOT/$language"
  for page_number in "${page_numbers[@]}"; do
    file_name="$(screenshot_file_name "$page_number")"
    source_file="$ARTIFACTS_ROOT/$language/$file_name"
    if [[ ! -f "$source_file" ]]; then
      printf '生成物が見つかりません: %s\n' "$source_file" >&2
      exit 1
    fi
    cp "$source_file" "$FASTLANE_SCREENSHOTS_ROOT/$language/$file_name"
  done
done

printf 'fastlane 配置完了: %s\n' "$FASTLANE_SCREENSHOTS_ROOT"
