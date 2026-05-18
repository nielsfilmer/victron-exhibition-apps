#!/usr/bin/env bash
# Launches App 3 (synced 3-screen slideshow) — RIGHT role.
# Designed to be run on login by com.intersolar.app3-right.plist.
#
# RIGHT is the display to the right of the macOS Main Display.
# This Chrome instance is a passive receiver of state broadcasts
# from the center; it has no controls and no user input.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)/app3-multi-screen"
INDEX_FILE="$APP_DIR/index.html"
PROFILE_DIR="$HOME/.kiosk-app3-right-profile"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

DISPLAYS_ENV="$(dirname "$0")/app3-displays.env"
if [[ ! -f "$DISPLAYS_ENV" ]]; then
  echo "✖ Missing $DISPLAYS_ENV" >&2; exit 1
fi
# shellcheck disable=SC1090
source "$DISPLAYS_ENV"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "App 3 index.html not found at $INDEX_FILE" >&2; exit 1
fi
if [[ ! -x "$CHROME" ]]; then
  echo "Google Chrome not found at $CHROME — install it first." >&2; exit 1
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
  --window-position=${RIGHT_X},${RIGHT_Y} \
  --window-size=${DISPLAY_WIDTH},${DISPLAY_HEIGHT} \
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
  --app="file://$INDEX_FILE?role=right"
