#!/usr/bin/env bash

# App Store スクリーンショット生成で共有する言語・ページ・出力先を定義する。
# 他スクリプトから source して使用する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACTS_ROOT="$SCRIPT_DIR/artifacts"
FASTLANE_SCREENSHOTS_ROOT="$PROJECT_ROOT/fastlane/screenshots"
HEADER_OUTPUT_ROOT="$PROJECT_ROOT/fastlane/creative_assets/product_page_header"
SUPPORTED_LANGUAGES=("ja" "en-US")
SUPPORTED_PAGE_NUMBERS=("1" "2" "3" "4" "5")

is_supported_language() {
  local requested_language="$1"
  local supported_language
  for supported_language in "${SUPPORTED_LANGUAGES[@]}"; do
    if [[ "$requested_language" == "$supported_language" ]]; then
      return 0
    fi
  done
  return 1
}

is_supported_page_number() {
  local requested_page_number="$1"
  local supported_page_number
  for supported_page_number in "${SUPPORTED_PAGE_NUMBERS[@]}"; do
    if [[ "$requested_page_number" == "$supported_page_number" ]]; then
      return 0
    fi
  done
  return 1
}

screenshot_file_name() {
  local page_number="$1"
  case "$page_number" in
    1) printf '%s\n' '01_snap_to_budget.png' ;;
    2) printf '%s\n' '02_receipt_scan.png' ;;
    3) printf '%s\n' '03_duplicate_detection.png' ;;
    4) printf '%s\n' '04_source_image.png' ;;
    5) printf '%s\n' '05_monthly_report.png' ;;
    *)
      printf '未対応のページ番号です: %s\n' "$page_number" >&2
      return 1
      ;;
  esac
}
