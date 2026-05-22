#!/usr/bin/env bash
# Launches App 1 (slideshow) in Chrome kiosk mode for the specified
# content version. App 1 ships in three versions — ESS, OL, Microgrid
# — each with its own config.js + media/ under
# app1-slideshow/versions/<name>/. The thin wrapper scripts
# (launch-app1-{ess,ol,microgrid}.sh) call this one with the matching
# version. Designed to be run on login via the per-version LaunchAgent
# plists; also runnable manually for testing.
#
# Usage:
#   ./launch-app1.sh ess
#   ./launch-app1.sh ol
#   ./launch-app1.sh microgrid
set -euo pipefail

VERSION="${1:-}"
case "$VERSION" in
  ess|ol|microgrid) : ;;
  '')
    echo "Usage: $0 {ess|ol|microgrid}" >&2
    exit 1 ;;
  *)
    echo "Unknown version: $VERSION (expected ess|ol|microgrid)" >&2
    exit 1 ;;
esac

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)/app1-slideshow"
INDEX_FILE="$APP_DIR/index.html"
# Each version gets its own persistent Chrome profile so installs
# don't bleed Chrome state across versions. Operator-friendly cleanup:
# `rm -rf ~/.kiosk-app1-<v>-profile` resets the picked version's
# Chrome to a fresh state without affecting the others.
PROFILE_DIR="$HOME/.kiosk-app1-$VERSION-profile"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "App 1 index.html not found at $INDEX_FILE" >&2
  exit 1
fi
if [[ ! -x "$CHROME" ]]; then
  echo "Google Chrome not found at $CHROME — install it first." >&2
  exit 1
fi

# Prevent display sleep & system sleep while the kiosk runs.
caffeinate -dimsu &
CAFFEINATE_PID=$!
trap 'kill "$CAFFEINATE_PID" 2>/dev/null || true' EXIT

# Strip Chrome's "restore session?" prompt after a crash.
PREFS="$PROFILE_DIR/Default/Preferences"
if [[ -f "$PREFS" ]]; then
  /usr/bin/sed -i '' 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREFS" || true
fi

exec "$CHROME" \
  --kiosk \
  --noerrdialogs \
  --no-first-run \
  --no-default-browser-check \
  --disable-infobars \
  --disable-translate \
  --disable-features=TranslateUI,InfiniteSessionRestore \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --autoplay-policy=no-user-gesture-required \
  --disable-session-crashed-bubble \
  --disable-background-networking \
  --disable-component-update \
  --disable-renderer-backgrounding \
  --check-for-update-interval=31536000 \
  --user-data-dir="$PROFILE_DIR" \
  --app="file://$INDEX_FILE?version=$VERSION"
