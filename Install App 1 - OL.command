#!/usr/bin/env bash
# Double-click this file in Finder to install App 1 (slideshow) with
# the OL content version as the kiosk that auto-starts on every login.
#
# Equivalent to running `./kiosk/install.sh app1-ol` in Terminal.
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
║  Install App 1 — OL content version (slideshow)              ║
╚══════════════════════════════════════════════════════════════╝

Installing the LaunchAgent that will auto-start App 1 (OL slideshow)
every time this Mac logs in. If any other App 1 version is currently
installed (ESS or Microgrid), it will be uninstalled first — only one
App 1 version may run at a time.

BANNER

./kiosk/install.sh app1-ol
RC=$?

echo
if [[ $RC -eq 0 ]]; then
  cat <<'OK'
✓ App 1 (OL) is installed.
  Reboot the Mac (or log out + back in) to verify the kiosk starts
  automatically. To start it right now without rebooting:
      launchctl start com.intersolar.app1-ol
OK
else
  echo "✖ Install failed (exit $RC). See the error message above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window."
echo
