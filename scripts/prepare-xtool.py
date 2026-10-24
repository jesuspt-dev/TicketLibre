#!/usr/bin/env python3
"""Generate literal plist values for xtool: Xcode build-setting tokens are not expanded by xtool."""
from pathlib import Path
import plistlib,shutil
root=Path(__file__).resolve().parents[1]
dest=root/'xtool-resources';dest.mkdir(exist_ok=True)
info=plistlib.loads((root/'TicketLibre/Info.plist').read_bytes())
info.update(CFBundleExecutable='TicketLibre',CFBundleIdentifier='org.ticketlibre.ios',CFBundleName='TicketLibre',UIDeviceFamily=[1])
info['CFBundleIcons']={'CFBundlePrimaryIcon':{'CFBundleIconFiles':['AppIcon60x60'],'UIPrerenderedIcon':False}}
assert all('$(' not in str(value) for value in info.values()),'Unresolved Xcode variable in xtool plist'
(dest/'Info.plist').write_bytes(plistlib.dumps(info))
icons=root/'TicketLibre/Assets.xcassets/AppIcon.appiconset'
for source,target in [('icon-1024.png','AppIcon.png'),('icon-60@2x.png','AppIcon60x60@2x.png'),('icon-60@3x.png','AppIcon60x60@3x.png')]:shutil.copyfile(icons/source,dest/target)
print('xtool resources ready:',info['CFBundleShortVersionString'],'build',info['CFBundleVersion'])
