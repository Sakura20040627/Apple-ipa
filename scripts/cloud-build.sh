#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/output
xcodebuild -version | tee build/output/toolchain.txt
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$PWD/build/PayCompass.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive 2>&1 | tee build/output/build.log
APP="$PWD/build/PayCompass.xcarchive/Products/Applications/PayCompass.app"
test -d "$APP"
mkdir -p build/package/Payload
cp -R "$APP" build/package/Payload/
(cd build/package && /usr/bin/zip -qr ../output/PayCompass-unsigned.ipa Payload)
printf '%s\n' 'Unsigned device build; requires signing before installation.' > build/output/UNSIGNED.txt
