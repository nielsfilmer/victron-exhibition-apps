#!/usr/bin/env bash
# Double-click this file in Finder to install App 2 (chapter video)
# as the kiosk that auto-starts on every login.
#
# Equivalent to running `./kiosk/install.sh app2` in Terminal.
#
# (.command files open in Terminal automatically. Don't run this
# from inside Terminal yourself — there's a "Press any key to close"
# prompt at the end that's only useful when Terminal opened the
# window for you.)

cd "$(dirname "$0")"

clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════╗
║  Install App 2 — Victron chapter-video kiosk                 ║
╚══════════════════════════════════════════════════════════════╝

Installing the LaunchAgent that will auto-start App 2 (fullscreen
video with invisible chapter buttons) every time this Mac logs in.

BANNER

./kiosk/install.sh app2
RC=$?

echo
if [[ $RC -eq 0 ]]; then
  cat <<'OK'
✓ App 2 is installed.
  Reboot the Mac (or log out + back in) to verify the kiosk starts
  automatically. To start it right now without rebooting:
      launchctl start com.intersolar.app2
OK
else
  echo "✖ Install failed (exit $RC). See the error message above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window."
echo
