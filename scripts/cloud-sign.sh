#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEMP_SIGN=$(mktemp -d "${RUNNER_TEMP:-/tmp}/paycompass-sign.XXXXXX")
KEYCHAIN="$TEMP_SIGN/signing.keychain-db"
KEYCHAIN_PASSWORD=$(uuidgen)
PROFILE_PATH=''
cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  if [ -n "$PROFILE_PATH" ]; then rm -f "$PROFILE_PATH"; fi
  rm -rf "$TEMP_SIGN"
}
trap cleanup EXIT
printf '%s' "$P12_BASE64" | base64 --decode > "$TEMP_SIGN/certificate.p12"
printf '%s' "$PROFILE_BASE64" | base64 --decode > "$TEMP_SIGN/profile.mobileprovision"
security cms -D -i "$TEMP_SIGN/profile.mobileprovision" > "$TEMP_SIGN/profile.plist"
PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$TEMP_SIGN/profile.plist")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$TEMP_SIGN/profile.plist")
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
cp "$TEMP_SIGN/profile.mobileprovision" "$PROFILE_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$TEMP_SIGN/certificate.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
export PROFILE_NAME
python3 - "$TEMP_SIGN/ExportOptions.plist" <<'PY'
import os,plistlib,sys
method=os.environ.get('EXPORT_METHOD') or 'release-testing'
if method not in ['release-testing','debugging','app-store-connect']:
 raise SystemExit('Unsupported IOS_EXPORT_METHOD')
with open(sys.argv[1],'wb') as f:
 plistlib.dump(dict(method=method,teamID=os.environ['TEAM_ID'],signingStyle='manual',provisioningProfiles={os.environ['BUNDLE_ID']:os.environ['PROFILE_NAME']}),f)
PY
xcodebuild -project PayCompass.xcodeproj -scheme PayCompass -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$PWD/build/PayCompass-signed.xcarchive" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" archive \
  2>&1 | tee build/output/signing-build.log
xcodebuild -exportArchive -archivePath "$PWD/build/PayCompass-signed.xcarchive" \
  -exportOptionsPlist "$TEMP_SIGN/ExportOptions.plist" -exportPath "$PWD/build/output/signed" \
  2>&1 | tee build/output/export.log
