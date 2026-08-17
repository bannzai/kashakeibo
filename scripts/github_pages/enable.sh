#!/usr/bin/env bash
set -euo pipefail

repository="${1:-bannzai/kashakeibo}"

# Issue 18 の変更が main に入る前には Pages を有効化しない。
if ! gh api --silent "repos/${repository}/contents/docs/PrivacyPolicy-en.md?ref=main"; then
  echo "main に Issue 18 の変更がマージされていません: ${repository}" >&2
  exit 1
fi

if pages_configuration="$(gh api "repos/${repository}/pages" 2>&1)"; then
  pages_exists=true
elif [[ "${pages_configuration}" == *"HTTP 404"* ]]; then
  pages_exists=false
  pages_configuration=''
else
  printf '%s\n' "${pages_configuration}" >&2
  exit 1
fi

if [[ "${pages_exists}" == true ]] &&
  [[ "$(jq -r '.source.branch // empty' <<<"${pages_configuration}")" == "main" ]] &&
  [[ "$(jq -r '.source.path // empty' <<<"${pages_configuration}")" == "/docs" ]]; then
  echo "GitHub Pages は main の /docs で有効です: ${repository}"
  exit 0
fi

request_body='{"build_type":"legacy","source":{"branch":"main","path":"/docs"}}'
if [[ "${pages_exists}" == true ]]; then
  gh api --silent --method PUT "repos/${repository}/pages" --input - <<<"${request_body}"
else
  gh api --silent --method POST "repos/${repository}/pages" --input - <<<"${request_body}"
fi

echo "GitHub Pages を main の /docs で有効化しました: ${repository}"
