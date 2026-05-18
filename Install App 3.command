#!/usr/bin/env bash
# Double-click this file in Finder to install App 3 (3-screen synced
# slideshow) as the kiosk that auto-starts on every login.
#
# Installs FOUR LaunchAgents: the localhost WebSocket relay that
# syncs the screens, plus one Chrome --kiosk instance per display
# (center / left / right).
#
# Equivalent to running `./kiosk/install.sh app3` in Terminal.
#
# (.command files open in Terminal automatically. Don't run this
# from inside Terminal yourself — there's a "Press any key to close"
# prompt at the end that's only useful when Terminal opened the
# window for you.)

# Anchor to this script's own folder so the command works no matter
# where Finder launched it from.
cd "$(dirname "$0")"

clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════╗
║  Install App 3 — Victron 3-screen synced kiosk               ║
╚══════════════════════════════════════════════════════════════╝

Installing FOUR LaunchAgents that auto-start App 3 every login:
  • com.intersolar.app3-ws     (localhost WebSocket sync relay)
  • com.intersolar.app3-center (Chrome --kiosk on the center display)
  • com.intersolar.app3-left   (Chrome --kiosk on the left display)
  • com.intersolar.app3-right  (Chrome --kiosk on the right display)

⚠ Before continuing, complete kiosk/INSTALL.md §3.7:
  - all 3 displays plugged in and arranged in System Settings
  - center display set as Main Display
  - kiosk/app3-displays.env matches your resolution + layout

BANNER

# Force the operator to acknowledge the §3.7 prerequisites before
# the install runs. Pressing any key proceeds; Ctrl+C aborts cleanly
# (read returns non-zero on signal, which the || exit propagates).
read -n 1 -s -r -p "Press any key to continue once §3.7 is done, or Ctrl+C to abort..." || { echo; echo "Aborted."; exit 1; }
echo
echo

./kiosk/install.sh app3
RC=$?

echo
if [[ $RC -eq 0 ]]; then
  cat <<'OK'
✓ App 3 is installed.
  Reboot the Mac (or log out + back in) to verify all 4 services
  come up automatically and Chrome opens on all 3 displays.
  To start them right now without rebooting:
      launchctl start com.intersolar.app3-ws
      launchctl start com.intersolar.app3-center
      launchctl start com.intersolar.app3-left
      launchctl start com.intersolar.app3-right
OK
else
  echo "✖ Install failed (exit $RC). See the error message above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window."
echo
