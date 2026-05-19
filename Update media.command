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
  - REPLACE the media/ folder AND config.js for any app whose folder
    is in the zip (app1-slideshow / app2-chapters / app3-multi-screen),
  - delete the downloaded zip + everything else,
  - restart the running kiosk so the new content is on screen.

Each app's media/ + config.js are independent — the zip may include
either, both, or neither for any app. Anything missing is left alone.

HTML, CSS, fonts, launch scripts, the ws-relay binary, and
app3-displays.env — never touched.

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
