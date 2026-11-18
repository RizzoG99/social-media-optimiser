#!/bin/zsh
set -eu
cd "${0:A:h:h}"
swift build -c release
APP="$PWD/.build/SocialFrame.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/SocialFrame" "$APP/Contents/MacOS/SocialFrame"
# SwiftPM can record the deployment target as the SDK version (sdk 14.0). AppKit
# then treats the app as linked before macOS 26 and disables the system Liquid
# Glass design. Record the SDK actually used, keeping the minimum system version.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
MIN_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)"
xcrun vtool -set-build-version macos "$MIN_VERSION" "$SDK_VERSION" -replace \
    -output "$APP/Contents/MacOS/SocialFrame" "$APP/Contents/MacOS/SocialFrame"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# SwiftPM resource accessors look beside the executable/main bundle on macOS.
for resource_bundle in "$BIN_DIR"/SocialFrame_*.bundle; do
    ditto "$resource_bundle" "$APP/Contents/Resources/${resource_bundle:t}"
done
# SwiftUI literal labels use the main bundle; AppKit also reads its language.
for language_folder in Sources/SocialFrame/Resources/*.lproj; do
    ditto "$language_folder" "$APP/Contents/Resources/${language_folder:t}"
done
/usr/bin/python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib, sys
from pathlib import Path
plist = Path(sys.argv[1])
info = plistlib.loads(plist.read_bytes())
info['CFBundleLocalizations'] = sorted(p.stem for p in Path('Sources/SocialFrame/Resources').glob('*.lproj'))
plist.write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - "$APP"
printf '%s\n' "$APP"
