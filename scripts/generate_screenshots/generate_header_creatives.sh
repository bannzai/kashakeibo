#!/usr/bin/env bash

# スクリーンショットと同じ配色・タイポグラフィで Product Page Header を生成する。
# 引数なしで日本語・英語を生成し、-l で1言語に絞れる。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/appstore_screenshot_env.sh"

requested_language="all"

while getopts ':l:h' option; do
  case "$option" in
    l) requested_language="$OPTARG" ;;
    h)
      printf 'Usage: %s [-l language]\n' "$0"
      exit 0
      ;;
    :|?)
      printf 'Usage: %s [-l language]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ "$requested_language" == "all" ]]; then
  file_pattern='*.png'
else
  file_pattern="$requested_language.png"
fi

# テンプレート更新で対象ロケールが減っても古い成果物を残さないよう初期化する。
if [[ -d "$HEADER_OUTPUT_ROOT" ]]; then
  find "$HEADER_OUTPUT_ROOT" -maxdepth 1 -type f -name "$file_pattern" -delete
fi

cd "$PROJECT_ROOT"
flutter test \
  test/features/appstore_screenshot/appstore_screenshot_test.dart \
  --plain-name 'App Store assets を生成する' \
  --dart-define=GENERATE_APPSTORE_ASSETS=true \
  --dart-define=APPSTORE_ASSET_KIND=header \
  --dart-define=APPSTORE_ASSET_LANGUAGE="$requested_language" \
  --dart-define=APPSTORE_HEADER_OUTPUT_ROOT="$HEADER_OUTPUT_ROOT"

generated_files=()
while IFS= read -r generated_file; do
  generated_files+=("$generated_file")
done < <(find "$HEADER_OUTPUT_ROOT" -maxdepth 1 -type f -name "$file_pattern" -print | sort)
if [[ "${#generated_files[@]}" -eq 0 ]]; then
  printf '生成された Product Page Header が見つかりません: %s/%s\n' \
    "$HEADER_OUTPUT_ROOT" "$file_pattern" >&2
  exit 1
fi
xcrun swift "$SCRIPT_DIR/strip_png_alpha.swift" "${generated_files[@]}"

printf 'Product Page Header 生成完了: %s\n' "$HEADER_OUTPUT_ROOT"
