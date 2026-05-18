#!/usr/bin/env bash
# Launches the localhost-only WebSocket relay used by App 3 to sync the
# three Chrome --kiosk instances (center / left / right).
#
# The kiosk JS auto-reconnects with backoff if the relay isn't up yet,
# so there's no ordering requirement between this LaunchAgent and the
# three Chrome ones — but starting the relay first means satellites
# pick up state without a visible reconnect delay.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Pick the right binary for this Mac's CPU. uname -m reports `arm64` on
# Apple Silicon and `x86_64` on Intel — those are the suffixes the
# build script (kiosk/ws-relay/build.sh) drops into kiosk/bin/.
ARCH="$(uname -m)"
BIN="$PROJECT_DIR/kiosk/bin/kiosk-ws-relay-$ARCH"

if [[ ! -x "$BIN" ]]; then
  echo "✖ Relay binary not found or not executable: $BIN" >&2
  echo "  Expected for arch: $ARCH" >&2
  echo "  Rebuild with: cd kiosk/ws-relay && ./build.sh" >&2
  exit 1
fi

# Bind explicitly to 127.0.0.1 — the relay must NEVER be reachable from
# the network. (The binary defaults to 127.0.0.1 already; passing it
# explicitly is belt-and-braces, and serves as in-code documentation
# that this is a deliberate choice.)
exec "$BIN" -addr 127.0.0.1:8743
