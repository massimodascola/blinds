#!/bin/sh
# Installa (o aggiorna) Tendina con un solo comando:
#
#   curl -fsSL https://raw.githubusercontent.com/massimodascola/tendina/master/install.sh | sh
#
# Scarica il codice da GitHub, lo compila su questo Mac con gli strumenti di
# sviluppo di Apple e copia l'app in /Applications. Compilata qui, l'app non
# ha il blocco di quarantena dei file scaricati: nessun avviso di Gatekeeper.
# I messaggi sono in italiano e in inglese perché è il primo contatto con chi
# arriva da GitHub.
set -eu

REPO="massimodascola/tendina"
RAMO="${TENDINA_RAMO:-master}"

errore() {
  printf '%s\n' "$@" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || errore "Tendina funziona solo su Mac. / Tendina runs on macOS only."
[ "$(uname -m)" = "arm64" ] || errore "Per ora Tendina si compila solo per Mac con Apple Silicon. / Apple Silicon Macs only for now."

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  errore "Mancano gli strumenti di sviluppo di Apple. Installali con: / Apple developer tools are missing. Install them with:" \
         "" \
         "  xcode-select --install" \
         "" \
         "Poi rilancia questo comando. / Then run this command again."
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Scarico Tendina... / Downloading Tendina..."
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$RAMO.tar.gz" | tar -xz -C "$TMP"

echo "Compilo e installo... / Building and installing..."
sh "$TMP/tendina-$RAMO/build.sh" --installa
