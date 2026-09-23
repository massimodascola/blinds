#!/bin/sh
# Compila Tendina.app nella cartella build/.
# Uso:  sh build.sh             solo compilazione
#       sh build.sh --installa  compila, copia in /Applications e avvia
set -eu
cd "$(dirname "$0")"

APP=build/Tendina.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13 \
  Sources/*.swift -o "$APP/Contents/MacOS/Tendina"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Firma locale "ad hoc": basta per usarla su questo Mac.
codesign --force --sign - "$APP"
echo "Compilata: $APP"

if [ "${1:-}" = "--installa" ]; then
  pkill -x Tendina 2>/dev/null || true
  sleep 1
  rm -rf /Applications/Tendina.app
  cp -R "$APP" /Applications/
  open /Applications/Tendina.app
  echo "Installata in /Applications e avviata."
fi
