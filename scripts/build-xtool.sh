#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xtool_command="${XTOOL_BIN:-xtool}"
if ! command -v "$xtool_command" >/dev/null 2>&1 && [[ ! -x "$xtool_command" ]]; then
  echo 'xtool is not installed. Install the official xtool release and Swift toolchain.'; exit 69
fi
"$xtool_command" --version
if [[ "$(uname -s)" != Darwin ]]; then
  sdk_status="$("$xtool_command" sdk status)"
  printf '%s\n' "$sdk_status"
  if [[ "$sdk_status" != *'Darwin SDK is installed'* ]]; then
    echo 'Cannot compile iOS: the official Darwin/iOS SDK is missing.'
    echo 'Download Xcode.xip from your Apple account, then run: xtool sdk install --slim /path/to/Xcode.xip'
    exit 66
  fi
fi
python3 scripts/prepare-xtool.py
"$xtool_command" dev build --configuration release --ipa
if [[ ! -f xtool/TicketLibre.ipa ]]; then echo 'xtool did not produce the expected IPA.'; exit 1; fi
mkdir -p build
cp xtool/TicketLibre.ipa build/TicketLibre-v1.0.2-iPhone-unsigned.ipa
python3 - <<'PY'
from pathlib import Path
import zipfile,plistlib,hashlib,struct
ipa=Path('build/TicketLibre-v1.0.2-iPhone-unsigned.ipa')
with zipfile.ZipFile(ipa) as z:
 assert z.testzip() is None,'Corrupt IPA archive'
 base='Payload/TicketLibre.app/'
 info=plistlib.loads(z.read(base+'Info.plist'))
 assert info['CFBundleExecutable']=='TicketLibre'
 assert info['CFBundleShortVersionString']=='1.0.2' and info['CFBundleVersion']=='3'
 assert info['CFBundleIdentifier']=='org.ticketlibre.ios'
 binary=z.read(base+'TicketLibre')
 assert binary[:4]==b'\xcf\xfa\xed\xfe','Expected 64-bit Mach-O executable'
 assert struct.unpack('<I',binary[4:8])[0]==0x0100000C,'Expected arm64 iPhone executable'
 assert base+'PrivacyInfo.xcprivacy' in z.namelist()
 assert base+'AppIcon.png' in z.namelist()
checksum=hashlib.sha256(ipa.read_bytes()).hexdigest()
ipa.with_suffix(ipa.suffix+'.sha256').write_text(checksum+'  '+ipa.name+'\n')
print('Verified IPA archive, arm64 Mach-O, version, privacy manifest and icon. This does not test installation or iPhone behavior.')
PY
