#!/bin/bash
# Produces a signed archive and App Store Connect export. Does not upload or invite testers.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo '必须在安装完整 Xcode 的 Mac 上运行。' >&2
  exit 1
fi
: "${SKYPLATE_TEAM_ID:?设置 SKYPLATE_TEAM_ID 为 Apple Developer Team ID}"
: "${SKYPLATE_BUNDLE_ID:?设置 SKYPLATE_BUNDLE_ID 为已注册的主 App Bundle ID}"
if [[ ! "$SKYPLATE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo 'Team ID 应为 10 位大写字母或数字。' >&2; exit 1
fi
if [[ ! "$SKYPLATE_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || [[ "$SKYPLATE_BUNDLE_ID" == com.example.* ]]; then
  echo '请使用你自己的、与 App Store Connect 一致的 Bundle ID。' >&2; exit 1
fi
skyplate_build="${SKYPLATE_BUILD_NUMBER:-2}"
if [[ ! "$skyplate_build" =~ ^[1-9][0-9]{0,3}$ ]]; then
  echo 'Build number 必须是 1–9999 的整数，且高于之前上传的版本。' >&2; exit 1
fi
xcodebuild -version
skyplate_output="$(mktemp -d "$PWD/SkyPlate-Release-${skyplate_build}-XXXXXX")"
xcodebuild -project SkyPlate.xcodeproj -scheme SkyPlate -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$skyplate_output/SkyPlate.xcarchive" \
  DEVELOPMENT_TEAM="$SKYPLATE_TEAM_ID" SKYPLATE_BUNDLE_ID="$SKYPLATE_BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$skyplate_build" -allowProvisioningUpdates archive
cat > "$skyplate_output/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>export</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>$SKYPLATE_TEAM_ID</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$skyplate_output/SkyPlate.xcarchive" \
  -exportPath "$skyplate_output/Export" -exportOptionsPlist "$skyplate_output/ExportOptions.plist" \
  -allowProvisioningUpdates
printf '\n归档及导出成功：%s\n尚未上传 TestFlight。可在 Xcode Organizer 打开归档并选择 Distribute App。\n' "$skyplate_output"
open "$skyplate_output/SkyPlate.xcarchive"
