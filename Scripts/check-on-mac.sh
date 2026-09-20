#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo '请在安装 Xcode 的 Mac 上执行。'
  exit 1
fi
xcodebuild -project SkyPlate.xcodeproj -scheme SkyPlate \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/SkyPlateBuild CODE_SIGNING_ALLOWED=NO build
