#!/usr/bin/env bash
# Launches App 2 (chapter-buttons) in Chrome kiosk mode.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)/app2-chapters"
INDEX_FILE="$APP_DIR/index.html"
PROFILE_DIR="$HOME/.kiosk-app2-profile"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "App 2 index.html not found at $INDEX_FILE" >&2
  exit 1
fi
if [[ ! -x "$CHROME" ]]; then
  echo "Google Chrome not found at $CHROME — install it first." >&2
  exit 1
fi

caffeinate -dimsu &
CAFFEINATE_PID=$!
trap 'kill "$CAFFEINATE_PID" 2>/dev/null || true' EXIT

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
  --app="file://$INDEX_FILE"
