#!/bin/sh
# Builds Tendina.app into build/.
# Usage:  sh build.sh            build only
#         sh build.sh --install  build, copy to /Applications and launch
set -eu
cd "$(dirname "$0")"

APP=build/Tendina.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13 \
  Sources/*.swift -o "$APP/Contents/MacOS/Tendina"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Tendina.icns "$APP/Contents/Resources/Tendina.icns"
cp -R Resources/en.lproj Resources/it.lproj "$APP/Contents/Resources/"

# Ad hoc signature: enough to run the app on the Mac that built it.
codesign --force --sign - "$APP"
echo "Built: $APP"

case "${1:-}" in
  --install|--installa)  # --installa is the Italian name used by version 1.0.0
    pkill -x Tendina 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Tendina.app
    cp -R "$APP" /Applications/
    open /Applications/Tendina.app
    echo "Installed in /Applications and launched."
    ;;
esac
