#!/bin/sh
# Rigenera Resources/Tendina.icns dal disegno in tools/disegna-icona.swift.
# Serve solo se si cambia il disegno; poi: sh build.sh --installa
set -eu
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
swift tools/disegna-icona.swift "$TMP/icona.png"
mkdir "$TMP/Tendina.iconset"
for dim in 16 32 128 256 512; do
  sips -z $dim $dim "$TMP/icona.png" --out "$TMP/Tendina.iconset/icon_${dim}x${dim}.png" >/dev/null
  doppia=$((dim * 2))
  sips -z $doppia $doppia "$TMP/icona.png" --out "$TMP/Tendina.iconset/icon_${dim}x${dim}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/Tendina.iconset" -o Resources/Tendina.icns
cp "$TMP/icona.png" Resources/icona.png
rm -rf "$TMP"
echo "Creata Resources/Tendina.icns"
