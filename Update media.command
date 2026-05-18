#!/usr/bin/env bash
# Double-click this file in Finder to download the latest media zip
# from the content team's URL and replace the kiosk's media/ folders.
#
# Equivalent to running `./kiosk/content-update.sh` in Terminal.
#
# Set the URL once by editing kiosk/content-url.txt — the content team
# provides it.

cd "$(dirname "$0")"

clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════╗
║  Update media — fetch latest slide media from content team   ║
╚══════════════════════════════════════════════════════════════╝

This will:
  - download the zip from the URL in kiosk/content-url.txt,
  - REPLACE the media in app1-slideshow/media/ and app2-chapters/media/,
  - delete the downloaded zip + everything else,
  - restart the running kiosk so the new media is on screen.

Config files, HTML, JS, fonts — left alone.

BANNER

./kiosk/content-update.sh
RC=$?

echo
if [[ $RC -eq 0 ]]; then
  echo "✓ Media updated."
else
  echo "✖ Update failed (exit $RC). See the error message above."
fi

echo
read -n 1 -s -r -p "Press any key to close this window."
echo
