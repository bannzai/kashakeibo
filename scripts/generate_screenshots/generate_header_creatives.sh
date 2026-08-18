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

if [[ "$requested_language" != "all" ]] && ! is_supported_language "$requested_language"; then
  printf '未対応の言語です: %s（対応: ja, en-US）\n' "$requested_language" >&2
  exit 2
fi
if [[ "$requested_language" == "all" ]]; then
  file_pattern='*.png'
  expected_file_count="${#SUPPORTED_LANGUAGES[@]}"
else
  file_pattern="$requested_language.png"
  expected_file_count=1
fi

# 生成失敗時も追跡済みの正常なヘッダーを維持するため、中間出力だけを初期化する。
mkdir -p "$HEADER_ARTIFACTS_ROOT"
find "$HEADER_ARTIFACTS_ROOT" -maxdepth 1 -type f -name "$file_pattern" -delete

cd "$PROJECT_ROOT"
flutter test \
  test/features/appstore_screenshot/appstore_screenshot_test.dart \
  --plain-name 'App Store assets を生成する' \
  --dart-define=GENERATE_APPSTORE_ASSETS=true \
  --dart-define=APPSTORE_ASSET_KIND=header \
  --dart-define=APPSTORE_ASSET_LANGUAGE="$requested_language" \
  --dart-define=APPSTORE_HEADER_OUTPUT_ROOT="$HEADER_ARTIFACTS_ROOT"

generated_files=()
while IFS= read -r generated_file; do
  generated_files+=("$generated_file")
done < <(find "$HEADER_ARTIFACTS_ROOT" -maxdepth 1 -type f -name "$file_pattern" -print | sort)
if [[ "${#generated_files[@]}" -ne "$expected_file_count" ]]; then
  printf '生成された Product Page Header の数が不正です: %s（期待: %s）\n' \
    "${#generated_files[@]}" "$expected_file_count" >&2
  exit 1
fi
xcrun swift "$SCRIPT_DIR/strip_png_alpha.swift" "${generated_files[@]}"

# 全画像の生成・検証・alpha 除去が成功した後だけ、既存成果物を置き換える。
mkdir -p "$HEADER_OUTPUT_ROOT"
for generated_file in "${generated_files[@]}"; do
  cp "$generated_file" "$HEADER_OUTPUT_ROOT/$(basename "$generated_file")"
done

printf 'Product Page Header 生成完了: %s\n' "$HEADER_OUTPUT_ROOT"
