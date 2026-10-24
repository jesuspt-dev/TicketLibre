#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/select-xcode.sh
xcrun simctl list devices available --json > /tmp/ticketlibre-simulators.json
simulator_id="$(python3 - <<'PY'
import json
x=json.load(open('/tmp/ticketlibre-simulators.json'))
for runtime,devices in reversed(list(x['devices'].items())):
    if '.iOS-' in runtime:
        for device in devices:
            if device['isAvailable'] and device['name'].startswith('iPhone'):
                print(device['udid']);raise SystemExit(0)
raise SystemExit('No iPhone simulator installed. Download the iOS simulator runtime.')
PY
)"
xcodebuild -project TicketLibre.xcodeproj -scheme TicketLibre -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath build/TestDerivedData \
  -resultBundlePath build/TicketLibre-tests.xcresult CODE_SIGNING_ALLOWED=NO test
