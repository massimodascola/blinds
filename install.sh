#!/bin/sh
# Installs (or updates) Blinds with a single command:
#
#   curl -fsSL https://raw.githubusercontent.com/massimodascola/blinds/master/install.sh | sh
#
# Downloads the source from GitHub, builds it on this Mac with Apple's
# developer tools and copies the app to /Applications. Built locally, the app
# carries no quarantine flag, so Gatekeeper shows no warning.
set -eu

REPO="massimodascola/blinds"
BRANCH="${BLINDS_BRANCH:-master}"

fail() {
  printf '%s\n' "$@" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "Blinds runs on macOS only."
[ "$(uname -m)" = "arm64" ] || fail "Blinds currently builds for Apple Silicon Macs only."

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  fail "Apple's developer tools are missing. Install them with:" \
       "" \
       "  xcode-select --install" \
       "" \
       "then run this command again."
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Blinds..."
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMP"

echo "Building and installing..."
sh "$TMP/blinds-$BRANCH/build.sh" --install
