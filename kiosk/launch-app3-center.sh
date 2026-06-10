#!/usr/bin/env bash
# Launches App 3 (synced 3-screen slideshow) — CENTER role.
# Designed to be run on login by com.intersolar.app3-center.plist,
# but also runnable manually.
#
# CENTER is the macOS Main Display (the one with the menu bar in
# System Settings → Displays → Arrange). It hosts the controls
# cluster and is authoritative for slide state — the other two
# Chrome instances mirror its broadcasts via the WS relay.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)/app3-multi-screen"
INDEX_FILE="$APP_DIR/index.html"
PROFILE_DIR="$HOME/.kiosk-app3-center-profile"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Load operator-edited display geometry.
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

# Prevent display sleep & system sleep while the kiosk runs.
caffeinate -dimsu &
CAFFEINATE_PID=$!
trap 'kill "$CAFFEINATE_PID" 2>/dev/null || true' EXIT

# Strip Chrome's "restore session?" prompt after a crash.
PREFS="$PROFILE_DIR/Default/Preferences"
if [[ -f "$PREFS" ]]; then
  /usr/bin/sed -i '' 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREFS" || true
fi

# Park the mouse pointer in the far bottom-right corner before Chrome
# takes over. App 3 has no visitor interaction, so Chrome's CSS
# `cursor: none` never gets the pointer-move it needs to engage, and a
# stray arrow would otherwise sit frozen on the slides (see CLAUDE.md
# pitfall #23). CGWarpMouseCursorPosition only repositions the cursor —
# it posts no event — so it needs NO Accessibility/TCC grant and runs
# prompt-free on a fresh kiosk Mac. Synchronous (not backgrounded), so
# unlike the caffeinate in pitfall #15 it leaves no orphan process.
# (999999,999999) clamps to the outermost corner of the display union —
# the least-visible resting spot (a single 1 px arrow remains there).
/usr/bin/osascript -l JavaScript \
  -e 'ObjC.import("CoreGraphics"); $.CGWarpMouseCursorPosition($.CGPointMake(999999, 999999))' \
  2>/dev/null || true

# --window-position + --window-size tell Chrome where to open the
# initial window; --kiosk then fullscreens it on the display that
# contains that point. macOS treats this the same as Cmd+Ctrl+F on the
# specific display, so each role lands on its assigned screen.
exec "$CHROME" \
  --kiosk \
  --window-position=${CENTER_X},${CENTER_Y} \
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
  --app="file://$INDEX_FILE?role=center"
