#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <owner> <repo> <tag>"
  echo "Example: $0 acme key-monitor v0.1.0"
  exit 1
fi

OWNER="$1"
REPO="$2"
TAG="$3"
BASE="https://github.com/${OWNER}/${REPO}/releases/download/${TAG}"

echo "Windows x64 URL: ${BASE}/key-monitor-win-x64.zip"
echo "Windows ARM64 URL: ${BASE}/key-monitor-win-arm64.zip"
echo ""
echo "Manifest snippet:"
cat <<EOF
"windows-x64": {
  "label": "Windows x64",
  "url": "${BASE}/key-monitor-win-x64.zip",
  "checksum": "sha256: replace-with-real-checksum"
},
"windows-arm64": {
  "label": "Windows ARM64",
  "url": "${BASE}/key-monitor-win-arm64.zip",
  "checksum": "sha256: replace-with-real-checksum"
}
EOF
