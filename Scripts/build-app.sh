#!/bin/bash
# Builds LifeInWeeks.app.
#
# SwiftPM produces a bare executable; a menu bar app needs a bundle with an
# Info.plist (LSUIElement, so it stays out of the Dock — PRD §6) and a
# signature. Ad-hoc signing is enough: the app is built and run on the same
# Mac, which is the whole distribution plan (PRD §8).
#
#   ./Scripts/build-app.sh            → debug build into dist/
#   ./Scripts/build-app.sh release    → release build into dist/
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-debug}"
APP="dist/LifeInWeeks.app"

swift build -c "$CONFIGURATION" --product LifeInWeeksApp
BINARY="$(swift build -c "$CONFIGURATION" --product LifeInWeeksApp --show-bin-path)/LifeInWeeksApp"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/LifeInWeeks"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Life in Weeks</string>
    <key>CFBundleDisplayName</key>     <string>Life in Weeks</string>
    <key>CFBundleExecutable</key>      <string>LifeInWeeks</string>
    <key>CFBundleIdentifier</key>      <string>com.mbm.LifeInWeeks</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <!-- Menu bar utility: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSSupportsAutomaticTermination</key> <false/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1

echo "Built $APP"
