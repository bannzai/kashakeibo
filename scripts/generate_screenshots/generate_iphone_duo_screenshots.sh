#!/usr/bin/env bash

# Flutter widget test で iPhone Duo (外側・内側ディスプレイ) の App Store スクリーンショットを生成する。
# 引数なしで日本語・英語の全画像 (言語ごとに外側 5 枚 + 内側 5 枚) を生成する。
# -l と -n で1言語・1ページに絞れる。
#
# 出力先は scripts/generate_screenshots/artifacts_iphone_duo/{lang}/{iphone_duo_outer,iphone_duo_inner}/ で、
# fastlane/screenshots へは配置しない。
# fastlane deliver 2.241.0 の deliver/lib/deliver/app_screenshot.rb の DEVICE_RESOLUTIONS に Duo の寸法が無く、
# 同じディレクトリに置くとアップロード全体が検証で止まるため、App Store Connect へは別経路で上げる (README)。
#
# 生成後に sips で全ファイルの寸法・alpha 無しを検査し、枚数が期待と一致しなければ exit 1 で終える。

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

selected_artifacts_root="$IPHONE_DUO_ARTIFACTS_ROOT"
language_count="${#SUPPORTED_LANGUAGES[@]}"
if [[ "$requested_language" != "all" ]]; then
  selected_artifacts_root="$IPHONE_DUO_ARTIFACTS_ROOT/$requested_language"
  language_count=1
fi
if [[ "$requested_page_number" == "0" ]]; then
  file_pattern='*.png'
  page_count=5
else
  page_prefix="$(printf '%02d' "$requested_page_number")"
  file_pattern="${page_prefix}_*.png"
  page_count=1
fi
# 外側・内側の 2 ディスプレイ分。
expected_file_count=$((language_count * page_count * 2))

# 同じ引数で再実行しても古い画像が残らないよう、対象生成物だけを初期化する。
if [[ -d "$selected_artifacts_root" ]]; then
  find "$selected_artifacts_root" -type f -name "$file_pattern" -delete
fi

cd "$PROJECT_ROOT"
flutter test \
  test/features/appstore_screenshot/appstore_screenshot_test.dart \
  --plain-name 'App Store assets を生成する' \
  --dart-define=GENERATE_APPSTORE_ASSETS=true \
  --dart-define=APPSTORE_ASSET_KIND=iphone_duo_screenshots \
  --dart-define=APPSTORE_ASSET_LANGUAGE="$requested_language" \
  --dart-define=APPSTORE_SCREENSHOT_PAGE="$requested_page_number" \
  --dart-define=APPSTORE_SCREENSHOT_OUTPUT_ROOT="$IPHONE_DUO_ARTIFACTS_ROOT"

generated_files=()
while IFS= read -r generated_file; do
  generated_files+=("$generated_file")
done < <(find "$selected_artifacts_root" -type f -name "$file_pattern" -print | sort)
if [[ "${#generated_files[@]}" -ne "$expected_file_count" ]]; then
  printf '生成枚数が期待と一致しません: %d 枚 (期待: %d 枚) %s/%s\n' \
    "${#generated_files[@]}" "$expected_file_count" "$selected_artifacts_root" "$file_pattern" >&2
  exit 1
fi
xcrun swift "$SCRIPT_DIR/strip_png_alpha.swift" "${generated_files[@]}"

# Apple の Screenshot specifications の iPhone Duo の寸法 (外側 1398×2034、内側は横 2853×2007)。
# strip_png_alpha.swift の後に sips で読み直し、ファイル名の表示種別どおりの寸法で alpha が無いことを確かめる。
for generated_file in "${generated_files[@]}"; do
  case "$(basename "$generated_file")" in
    *_iphone_duo_outer_*) expected_dimensions="1398x2034" ;;
    *_iphone_duo_inner_*) expected_dimensions="2853x2007" ;;
    *)
      printf '表示種別を判定できないファイル名です: %s\n' "$generated_file" >&2
      exit 1
      ;;
  esac
  actual_dimensions="$(sips -g pixelWidth -g pixelHeight "$generated_file" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {printf "%sx%s", w, h}')"
  actual_has_alpha="$(sips -g hasAlpha "$generated_file" | awk '/hasAlpha/ {print $2}')"
  if [[ "$actual_dimensions" != "$expected_dimensions" || "$actual_has_alpha" != "no" ]]; then
    printf '生成画像の検査に失敗しました: %s (寸法: %s, 期待: %s, hasAlpha: %s)\n' \
      "$generated_file" "$actual_dimensions" "$expected_dimensions" "$actual_has_alpha" >&2
    exit 1
  fi
done

printf 'iPhone Duo スクリーンショット生成完了 (%d 枚): %s\n' "${#generated_files[@]}" "$selected_artifacts_root"
printf '%s\n' "${generated_files[@]}"
