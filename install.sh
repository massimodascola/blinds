#!/bin/sh
# Installs (or updates) Tendina with a single command:
#
#   curl -fsSL https://raw.githubusercontent.com/massimodascola/tendina/master/install.sh | sh
#
# Downloads the source from GitHub, builds it on this Mac with Apple's
# developer tools and copies the app to /Applications. Built locally, the app
# carries no quarantine flag, so Gatekeeper shows no warning.
set -eu

REPO="massimodascola/tendina"
BRANCH="${TENDINA_BRANCH:-master}"

fail() {
  printf '%s\n' "$@" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "Tendina runs on macOS only."
[ "$(uname -m)" = "arm64" ] || fail "Tendina currently builds for Apple Silicon Macs only."

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  fail "Apple's developer tools are missing. Install them with:" \
       "" \
       "  xcode-select --install" \
       "" \
       "then run this command again."
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Tendina..."
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMP"

echo "Building and installing..."
sh "$TMP/tendina-$BRANCH/build.sh" --install
