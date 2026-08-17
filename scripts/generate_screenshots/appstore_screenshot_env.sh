#!/usr/bin/env bash

# App Store スクリーンショット生成で共有する言語・ページ・出力先を定義する。
# 他スクリプトから source して使用する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACTS_ROOT="$SCRIPT_DIR/artifacts"
FASTLANE_SCREENSHOTS_ROOT="$PROJECT_ROOT/fastlane/screenshots"
HEADER_OUTPUT_ROOT="$PROJECT_ROOT/fastlane/creative_assets/product_page_header"
