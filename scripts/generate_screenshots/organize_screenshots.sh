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
      printf 'Usage: %s [-l language] [-n positive-page-number]\n' "$0"
      exit 0
      ;;
    :|?)
      printf 'Usage: %s [-l language] [-n positive-page-number]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ "$requested_page_number" != "all" ]] && ! [[ "$requested_page_number" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ページ番号は正の整数で指定してください: %s\n' "$requested_page_number" >&2
  exit 2
fi

languages=()
if [[ "$requested_language" == "all" ]]; then
  while IFS= read -r language_directory; do
    languages+=("$(basename "$language_directory")")
  done < <(find "$ARTIFACTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sort)
else
  languages=("$requested_language")
fi
if [[ "${#languages[@]}" -eq 0 ]]; then
  printf '言語別の生成物が見つかりません: %s\n' "$ARTIFACTS_ROOT" >&2
  exit 1
fi

if [[ "$requested_page_number" == "all" ]]; then
  file_pattern='*.png'
else
  page_prefix="$(printf '%02d' "$requested_page_number")"
  file_pattern="${page_prefix}_*.png"
fi

for language in "${languages[@]}"; do
  source_files=()
  while IFS= read -r source_file; do
    source_files+=("$source_file")
  done < <(find "$ARTIFACTS_ROOT/$language" -maxdepth 1 -type f -name "$file_pattern" -print | sort)
  if [[ "${#source_files[@]}" -eq 0 ]]; then
    printf '生成物が見つかりません: %s/%s\n' "$ARTIFACTS_ROOT/$language" "$file_pattern" >&2
    exit 1
  fi

  target_directory="$FASTLANE_SCREENSHOTS_ROOT/$language"
  mkdir -p "$target_directory"
  # 部分生成でも同じページの旧端末クラス画像を残さず、配置処理を冪等にする。
  find "$target_directory" -maxdepth 1 -type f -name "$file_pattern" -delete
  for source_file in "${source_files[@]}"; do
    cp "$source_file" "$target_directory/$(basename "$source_file")"
  done
done

printf 'fastlane 配置完了: %s\n' "$FASTLANE_SCREENSHOTS_ROOT"
