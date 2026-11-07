#!/bin/bash
set -euo pipefail
mkdir -p build
DEVICE_ID="$(python3 - <<'PYCODE'
import json,subprocess
root=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
for runtime,devices in root['devices'].items():
    if 'iOS-26' not in runtime: continue
    for d in devices:
        if 'iPhone' in d['name']:
            print(d['udid']); raise SystemExit(0)
raise SystemExit('No available iOS 26 iPhone simulator found')
PYCODE
)"
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcodebuild -project SoraWeather.xcodeproj -scheme SoraWeather -configuration Debug -destination "id=$DEVICE_ID" -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO 2>&1 | tee build/simulator-build.log
xcrun simctl install "$DEVICE_ID" build/DerivedData/Build/Products/Debug-iphonesimulator/SoraWeather.app
xcrun simctl launch "$DEVICE_ID" app.sora.weather | tee build/simulator-launch.log
# Diagnostic screenshot; permission dialog and network results are not asserted by this smoke test.
xcrun simctl io "$DEVICE_ID" screenshot build/simulator.png
