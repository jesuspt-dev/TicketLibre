#!/bin/bash
# Optional, manual workflow: requires the owner's paid Apple developer membership and signing assets.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/select-xcode.sh
for name in P12_BASE64 P12_PASSWORD PROFILE_BASE64 APPLE_TEAM_ID APP_BUNDLE_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8_BASE64; do
  if [[ -z "${!name:-}" ]]; then echo "Missing required secret: $name"; exit 1; fi
done
sign_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/ticketlibre-sign.XXXXXX")"
keychain="$sign_dir/signing.keychain-db"
keychain_password="$(openssl rand -hex 24)"
profile_path=''
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  if [[ -n "$profile_path" ]]; then rm -f "$profile_path"; fi
  rm -rf "$sign_dir"
}
trap cleanup EXIT
export SIGN_DIR="$sign_dir"
python3 - <<'PY'
import os,base64,pathlib
p=pathlib.Path(os.environ['SIGN_DIR']);(p/'keys').mkdir()
for key,name in [('P12_BASE64','distribution.p12'),('PROFILE_BASE64','profile.mobileprovision')]:
 (p/name).write_bytes(base64.b64decode(os.environ[key],validate=True))
(p/'keys'/('AuthKey_'+os.environ['ASC_KEY_ID']+'.p8')).write_bytes(base64.b64decode(os.environ['ASC_KEY_P8_BASE64'],validate=True))
PY
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$sign_dir/distribution.p12" -P "$P12_PASSWORD" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
security cms -D -i "$sign_dir/profile.mobileprovision" > "$sign_dir/profile.plist"
python3 - <<'PY'
import os,plistlib,datetime,pathlib
p=pathlib.Path(os.environ['SIGN_DIR']);v=plistlib.loads((p/'profile.plist').read_bytes())
assert os.environ['APPLE_TEAM_ID'] in v['TeamIdentifier'],'Profile team mismatch'
assert v['Entitlements']['application-identifier']==os.environ['APPLE_TEAM_ID']+'.'+os.environ['APP_BUNDLE_ID'],'Profile bundle ID mismatch'
assert not v.get('ProvisionedDevices') and not v.get('ProvisionsAllDevices'),'An App Store profile is required'
assert v['ExpirationDate']>datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),'Expired profile'
(p/'profile-name').write_text(v['Name']);(p/'profile-uuid').write_text(v['UUID'])
options={'method':'app-store-connect','destination':'export','teamID':os.environ['APPLE_TEAM_ID'],'signingStyle':'manual','signingCertificate':'Apple Distribution','provisioningProfiles':{os.environ['APP_BUNDLE_ID']:v['Name']},'uploadSymbols':True,'manageAppVersionAndBuildNumber':False}
(p/'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
profile_name="$(cat "$sign_dir/profile-name")"
profile_uuid="$(cat "$sign_dir/profile-uuid")"
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
profile_path="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"
cp "$sign_dir/profile.mobileprovision" "$profile_path"
# A distinct build number is supplied by the manually dispatched workflow.
build_number="${IOS_BUILD_NUMBER:-1}"
xcodebuild -project TicketLibre.xcodeproj -scheme TicketLibre -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$sign_dir/TicketLibre.xcarchive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" PROVISIONING_PROFILE_SPECIFIER="$profile_name" \
  CURRENT_PROJECT_VERSION="$build_number" archive
# The workflow has already applied this build number to the ephemeral Info.plist.
xcodebuild -exportArchive -archivePath "$sign_dir/TicketLibre.xcarchive" \
  -exportOptionsPlist "$sign_dir/ExportOptions.plist" -exportPath "$sign_dir/export"
ipa_path="$(find "$sign_dir/export" -name '*.ipa' -print -quit)"
if [[ -z "$ipa_path" ]]; then echo 'No signed IPA was generated.'; exit 1; fi
export API_PRIVATE_KEYS_DIR="$sign_dir/keys"
xcrun altool --validate-app -f "$ipa_path" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
xcrun altool --upload-app -f "$ipa_path" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
