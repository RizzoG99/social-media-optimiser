#!/bin/zsh
set -eu
cd "${0:A:h:h}"
swift build -c release
APP="$PWD/.build/SocialFrame.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/SocialFrame" "$APP/Contents/MacOS/SocialFrame"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf '%s\n' "$APP"
