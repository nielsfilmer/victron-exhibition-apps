#!/usr/bin/env bash
# Double-click this file in Finder to pull the latest version of
# the kiosk apps from GitHub and reload the running kiosk.
#
# Equivalent to running `./kiosk/update.sh` in Terminal.
#
# (.command files open in Terminal automatically. Don't run this
# from inside Terminal yourself — there's a "Press any key to close"
# prompt at the end that's only useful when Terminal opened the
# window for you.)

cd "$(dirname "$0")"

clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════╗
║  Update — pull latest kiosk apps from GitHub                 ║
╚══════════════════════════════════════════════════════════════╝

BANNER

./kiosk/update.sh
RC=$?

echo
if [[ $RC -eq 0 ]]; then
  echo "✓ Update complete."
else
  echo "✖ Update failed (exit $RC). See the error message above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window."
echo
