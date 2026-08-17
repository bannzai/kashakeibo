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
      printf 'Usage: %s [-l ja|en-US]\n' "$0"
      exit 0
      ;;
    :|?)
      printf 'Usage: %s [-l ja|en-US]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if [[ "$requested_language" != "all" ]] && ! is_supported_language "$requested_language"; then
  printf '未対応の言語です: %s（対応: ja, en-US）\n' "$requested_language" >&2
  exit 2
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
generated_languages=("${SUPPORTED_LANGUAGES[@]}")
if [[ "$requested_language" != "all" ]]; then
  generated_languages=("$requested_language")
fi
for language in "${generated_languages[@]}"; do
  generated_files+=("$HEADER_OUTPUT_ROOT/$language.png")
done
xcrun swift "$SCRIPT_DIR/strip_png_alpha.swift" "${generated_files[@]}"

printf 'Product Page Header 生成完了: %s\n' "$HEADER_OUTPUT_ROOT"
