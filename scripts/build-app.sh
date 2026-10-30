#!/bin/bash
# Builds "Daily Note.app" into ./build. Pass --install to also copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Daily Note.app"

swift build -c release

if [[ ! -f build/AppIcon.icns ]]; then
    rm -rf build/AppIcon.iconset
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/DailyNote" "$APP/Contents/MacOS/DailyNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    osascript -e 'quit app "Daily Note"' 2>/dev/null || true
    rm -rf "/Applications/Daily Note.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/Daily Note.app"
fi
