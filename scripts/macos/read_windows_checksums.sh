#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <directory-containing-sha256-files>"
  echo "Example: $0 ~/Downloads/windows-assets"
  exit 1
fi

DIR="$1"

X64_FILE="${DIR}/key-monitor-win-x64.zip.sha256.txt"
ARM_FILE="${DIR}/key-monitor-win-arm64.zip.sha256.txt"

if [[ ! -f "$X64_FILE" ]]; then
  echo "Missing: $X64_FILE"
  exit 2
fi

if [[ ! -f "$ARM_FILE" ]]; then
  echo "Missing: $ARM_FILE"
  exit 2
fi

X64_HASH=$(awk '{print $1}' "$X64_FILE")
ARM_HASH=$(awk '{print $1}' "$ARM_FILE")

echo "windows-x64 checksum: sha256: ${X64_HASH}"
echo "windows-arm64 checksum: sha256: ${ARM_HASH}"
