#!/bin/bash
set -euo pipefail
# Select Xcode >= 26. Prefer a 26.x bundle; accept a newer default if 26 is absent.
ticketlibre_developer_dir="$(python3 - <<'PY'
from pathlib import Path
import re, subprocess
choices=[]
for path in Path('/Applications').glob('Xcode*.app'):
    dev=path/'Contents/Developer'
    try:
        value=subprocess.check_output(['/usr/bin/xcodebuild','-version'],env={**__import__('os').environ,'DEVELOPER_DIR':str(dev)},text=True)
        match=re.search(r'Xcode (\d+)(?:\.(\d+))?',value)
        if match:
            major,minor=int(match[1]),int(match[2] or 0)
            if major>=26: choices.append((major==26,major,minor,str(dev)))
    except Exception: pass
if not choices: raise SystemExit('No Xcode >=26 installation is available on this runner.')
print(max(choices)[3])
PY
)"
export DEVELOPER_DIR="$ticketlibre_developer_dir"
if [[ -n "${GITHUB_ENV:-}" ]]; then echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$GITHUB_ENV"; fi
xcode_version_output="$(xcodebuild -version)"
printf '%s\n' "$xcode_version_output"
xcodebuild -showsdks
sdk_output="$(xcodebuild -showsdks)"
if [[ "$sdk_output" != *iphoneos* ]]; then xcodebuild -downloadPlatform iOS; fi
if ! xcrun --sdk iphoneos --show-sdk-path; then
  xcodebuild -downloadPlatform iOS
  xcrun --sdk iphoneos --show-sdk-path
fi
# Xcode's generic device destination can require platform components beyond the SDK.
if ! xcodebuild -project TicketLibre.xcodeproj -scheme TicketLibre -showdestinations > /tmp/ticketlibre-destinations.txt 2>&1; then
  xcodebuild -downloadPlatform iOS
fi
cat /tmp/ticketlibre-destinations.txt
if /usr/bin/grep -q 'iOS .* is not installed' /tmp/ticketlibre-destinations.txt; then xcodebuild -downloadPlatform iOS; fi
