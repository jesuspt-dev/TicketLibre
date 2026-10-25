#!/usr/bin/env python3
"""Dependency-free structural validation, usable on Linux and macOS. Not an iOS build."""
from pathlib import Path
import json, plistlib, struct, xml.etree.ElementTree as ET, re
root=Path(__file__).resolve().parents[1]
info=plistlib.loads((root/'TicketLibre/Info.plist').read_bytes())
assert info['CFBundleShortVersionString']=='1.0.2' and info['CFBundleVersion']=='3'
assert info['NSCameraUsageDescription'] and info['NSFaceIDUsageDescription']
privacy=plistlib.loads((root/'TicketLibre/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
project=(root/'TicketLibre.xcodeproj/project.pbxproj').read_text()
for f in (root/'TicketLibre').rglob('*.swift'):
    assert f.relative_to(root/'TicketLibre').as_posix() in project, f'Missing target membership: {f}'
assert 'AppIcon' in project and 'org.ticketlibre.ios' in project
assert 'MARKETING_VERSION" = "1.0.2' in project and 'CURRENT_PROJECT_VERSION" = "3' in project
scheme=ET.parse(root/'TicketLibre.xcodeproj/xcshareddata/xcschemes/TicketLibre.xcscheme')
assert scheme.find('.//TestableReference') is not None
icon=root/'TicketLibre/Assets.xcassets/AppIcon.appiconset'
entries=json.loads((icon/'Contents.json').read_text())['images']
for entry in entries:
    data=(icon/entry['filename']).read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    width,height=struct.unpack('>II',data[16:24])
    expected=int(float(entry['size'].split('x')[0])*int(entry['scale'][0]))
    assert width==height==expected
    assert data[25] in [0,2], 'App icons must not have transparency'
assert any(e['size']=='1024x1024' for e in entries)
workflow=(root/'.github/workflows/build-ipa.yml').read_text()
for token in ['workflow_dispatch','macos-26','upload-artifact','test-ios.sh','build-xtool.sh']:assert token in workflow
build=(root/'scripts/build-unsigned.sh').read_text()
for token in ['generic/platform=iOS','CODE_SIGNING_ALLOWED=NO','CODE_SIGNING_REQUIRED=NO','Payload','shasum']:assert token in build
select=(root/'scripts/select-xcode.sh').read_text()
assert '-downloadPlatform iOS' in select
assert not re.search(r'xcodebuild[^\n]*\|[^\n]*head',select+build)
print(f"PASS: {len(list((root/'TicketLibre').rglob('*.swift')))} Swift target memberships, plist, privacy manifest, scheme, {len(entries)} icons and build configuration.")
print('This validates structure only. Xcode compilation and XCTest execution are separate required CI steps.')

xtool=plistlib.loads((root/'xtool-resources/Info.plist').read_bytes())
assert xtool['CFBundleExecutable']=='TicketLibre' and xtool['CFBundleVersion']=='3'
assert xtool['CFBundleShortVersionString']=='1.0.2'
assert '$(' not in str(xtool),'xtool plist must not contain Xcode tokens'
assert (root/'Package.swift').is_file() and (root/'xtool.yml').is_file()
assert 'dev build --configuration release --ipa' in (root/'scripts/build-xtool.sh').read_text()
print('PASS: SwiftPM manifest present; xtool plist has literal executable, bundle ID, version and build.')
