#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/output
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); print(next(v["udid"] for k,vs in d["devices"].items() if "iOS" in k for v in vs if "iPhone" in v["name"]))')
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath "$PWD/build/DerivedData" \
  -resultBundlePath "$PWD/build/Tests.xcresult" CODE_SIGNING_ALLOWED=NO test \
  2>&1 | tee build/output/tests.log
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
APP="$PWD/build/DerivedData/Build/Products/Debug-iphonesimulator/PayCompass.app"
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl launch "$DEVICE_ID" com.example.paycompass -appLanguage zh-Hant -appTheme sakura -sakuraTab 0
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/output/SakuraCard-home-zh.png
xcrun simctl terminate "$DEVICE_ID" com.example.paycompass
xcrun simctl launch "$DEVICE_ID" com.example.paycompass -appLanguage zh-Hant -appTheme ocean -sakuraTab 2
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/output/SakuraCard-shops-zh.png
xcrun simctl terminate "$DEVICE_ID" com.example.paycompass
xcrun simctl ui "$DEVICE_ID" appearance dark
xcrun simctl launch "$DEVICE_ID" com.example.paycompass -appLanguage zh-Hant -appTheme jade -sakuraTab 4
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/output/SakuraCard-settings-dark.png
xcrun simctl terminate "$DEVICE_ID" com.example.paycompass
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl launch "$DEVICE_ID" com.example.paycompass -appLanguage ja -appTheme violet -sakuraTab 1
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/output/SakuraCard-wallet-ja.png
