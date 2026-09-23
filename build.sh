#!/bin/sh
# Builds Blinds.app into build/.
# Usage:  sh build.sh            build only
#         sh build.sh --install  build, copy to /Applications and launch
set -eu
cd "$(dirname "$0")"

APP=build/Blinds.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13 \
  Sources/*.swift -o "$APP/Contents/MacOS/Blinds"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Blinds.icns "$APP/Contents/Resources/Blinds.icns"
cp -R Resources/en.lproj Resources/it.lproj "$APP/Contents/Resources/"

# Ad hoc signature: enough to run the app on the Mac that built it.
codesign --force --sign - "$APP"
echo "Built: $APP"

case "${1:-}" in
  --install|--installa)  # --installa is the Italian name used by version 1.0.0
    pkill -x Blinds 2>/dev/null || true
    # Blinds was called Tendina up to version 1.1: quit the old copy and move
    # it to the Trash, so the two don't fight over the same menu bar items.
    pkill -x Tendina 2>/dev/null || true
    sleep 1
    if [ -d /Applications/Tendina.app ]; then
      if command -v trash >/dev/null 2>&1 && trash -s /Applications/Tendina.app; then
        echo "Moved the old Tendina.app to the Trash."
      else
        echo "Note: the old /Applications/Tendina.app is still there. Move it to the Trash."
      fi
    fi
    rm -rf /Applications/Blinds.app
    cp -R "$APP" /Applications/
    open /Applications/Blinds.app
    echo "Installed in /Applications and launched."
    ;;
esac
