#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/select-xcode.sh
mkdir -p build
xcodebuild -project TicketLibre.xcodeproj -scheme TicketLibre -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' build
app_path="$PWD/build/DerivedData/Build/Products/Release-iphoneos/TicketLibre.app"
if [[ ! -d "$app_path" ]]; then echo 'TicketLibre.app was not produced.'; exit 1; fi
rm -rf build/Package
mkdir -p build/Package/Payload
cp -R "$app_path" build/Package/Payload/
# Remove previous output so zip cannot retain stale entries on a local rebuild.
rm -f build/TicketLibre-v1.0.1-iPhone-unsigned.ipa
(cd build/Package && /usr/bin/zip -qr ../TicketLibre-v1.0.1-iPhone-unsigned.ipa Payload)
/usr/bin/unzip -t build/TicketLibre-v1.0.1-iPhone-unsigned.ipa
(cd build && /usr/bin/shasum -a 256 TicketLibre-v1.0.1-iPhone-unsigned.ipa > TicketLibre-v1.0.1-iPhone-unsigned.ipa.sha256)
