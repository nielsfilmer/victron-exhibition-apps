#!/usr/bin/env bash
# Fetch the latest media package from the content team's hosting and
# replace the kiosk apps' media/ folders with the new content.
#
# Usage:
#   ./kiosk/content-update.sh
#
# Workflow:
#   1. Read the zip URL from kiosk/content-url.txt
#   2. Download to a temp dir
#   3. Unzip
#   4. Locate each app's media/ folder inside the extracted tree
#      (at root, or one level deep): app1-slideshow/media/,
#      app2-chapters/media/, app3-multi-screen/media/
#   5. REPLACE the local media/ folders with the new content
#      (existing files are removed first)
#   6. Delete the temp dir + everything else from the zip
#   7. Restart any loaded kiosk LaunchAgent so the running kiosk
#      picks up the new media
#
# Notes:
#   - Only the media/ folders are touched. Config files, HTML, JS,
#     CSS, fonts, the launch scripts — all left alone.
#   - To restore the original committed media (if a content update
#     went wrong), run:
#       git checkout -- app1-slideshow/media app2-chapters/media app3-multi-screen/media
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$PROJECT_DIR/kiosk/content-url.txt"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# 1. Read the URL (first non-blank, non-comment line).
#    Done with a pure-bash read loop on purpose — a `grep -v … | head` pipeline
#    is killed by `set -o pipefail` when grep finds no matches (i.e. the file
#    has only comments / is empty), and we want to fall through to the friendly
#    "no URL set" error below instead of dying silently.
if [[ ! -f "$URL_FILE" ]]; then
  red "✖ $URL_FILE is missing."
  echo "  Re-clone the repo (it's tracked in git)."
  exit 1
fi
URL=""
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*$    ]] && continue   # blank
  [[ "$line" =~ ^[[:space:]]*\#   ]] && continue   # comment
  URL="${line#"${line%%[![:space:]]*}"}"           # ltrim
  URL="${URL%"${URL##*[![:space:]]}"}"             # rtrim
  URL="${URL%% *}"                                 # first whitespace-separated token
  break
done < "$URL_FILE"
if [[ -z "${URL:-}" ]]; then
  red "✖ No URL set in $URL_FILE."
  echo "  Open the file in any text editor, paste the content-team's"
  echo "  zip URL on a line below the comments, save, and re-run this"
  echo "  script."
  exit 1
fi
if [[ "$URL" == *PLACEHOLDER* || "$URL" == *example.com* ]]; then
  red "✖ The URL in $URL_FILE is still a placeholder ($URL)."
  echo "  Replace it with the real zip URL from the content team."
  exit 1
fi

# 2. Sanity-check the URL format (basic — curl will catch the rest).
case "$URL" in
  http://*|https://*) : ;;  # ok
  *)
    red "✖ URL must start with http:// or https:// — got: $URL"
    exit 1 ;;
esac

# 3. Make a temp dir + auto-clean on exit
TMP="$(mktemp -d -t content-update.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

ZIP="$TMP/content.zip"
yellow "→ Downloading content package…"
echo "    $URL"
if ! curl -sSLf --max-time 600 -o "$ZIP" "$URL"; then
  red "✖ Download failed."
  echo "  Check that the URL is reachable and not behind login."
  exit 1
fi

ZIP_BYTES="$(stat -f%z "$ZIP" 2>/dev/null || stat -c%s "$ZIP")"
green "✓ Downloaded $(printf '%.1f MB' "$(echo "$ZIP_BYTES / 1024 / 1024" | bc -l)")."

# 4. Unzip
yellow "→ Extracting…"
mkdir -p "$TMP/unzipped"
if ! unzip -q "$ZIP" -d "$TMP/unzipped"; then
  red "✖ Extraction failed — the downloaded file may not be a valid zip."
  exit 1
fi

# 5. Locate each app's media folder in the extracted tree.
#    Accept either flat layout (app1-slideshow/media/) or nested under
#    a single top-level folder (foo/app1-slideshow/media/).
find_media_dir() {
  local app="$1"
  local cand
  for cand in \
      "$TMP/unzipped/$app/media" \
      "$TMP"/unzipped/*/"$app"/media; do
    if [[ -d "$cand" ]]; then echo "$cand"; return 0; fi
  done
  return 1
}

# 6. Replace local media/ with extracted media/
APPS=(app1-slideshow app2-chapters app3-multi-screen)
REPLACED=0
SKIPPED=()
for app in "${APPS[@]}"; do
  if SRC="$(find_media_dir "$app")"; then
    DEST="$PROJECT_DIR/$app/media"
    yellow "→ Replacing $app/media (from $SRC)…"
    rm -rf "$DEST"
    mkdir -p "$DEST"
    # Copy contents (the dot-slash form preserves dotfiles + avoids
    # nesting the source folder name).
    cp -R "$SRC"/. "$DEST"/
    REPLACED=$((REPLACED + 1))
  else
    SKIPPED+=("$app")
  fi
done

if [[ "$REPLACED" -eq 0 ]]; then
  red "✖ No media folders were replaced — the zip's layout doesn't match"
  echo "  the expected structure. See kiosk/content-url.txt for the"
  echo "  layout the script expects."
  exit 1
fi

green "✓ Replaced $REPLACED media folder(s) with new content."
if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
  yellow "  (No media for: ${SKIPPED[*]} — left untouched.)"
fi

# 7. Restart any loaded kiosk LaunchAgent so the kiosk picks up the
#    new media. Same kickstart approach as kiosk/update.sh — kills the
#    running Chrome and re-launches.
UID_NUM="$(id -u)"
RELOADED=0
KIOSK_LABELS=(
  com.intersolar.app1
  com.intersolar.app2
  com.intersolar.app3-ws
  com.intersolar.app3-center
  com.intersolar.app3-left
  com.intersolar.app3-right
)
for label in "${KIOSK_LABELS[@]}"; do
  PLIST="$HOME/Library/LaunchAgents/$label.plist"
  if [[ -f "$PLIST" ]] && launchctl list 2>/dev/null | grep -q "$label"; then
    yellow "→ Restarting $label…"
    launchctl kickstart -k "gui/$UID_NUM/$label"
    RELOADED=$((RELOADED + 1))
  fi
done

if [[ "$RELOADED" -gt 0 ]]; then
  green "✓ Kiosk restarted with the new media. (Brief black screen during restart.)"
else
  yellow "→ No kiosk LaunchAgent is currently loaded — media replaced on disk,"
  echo "  but no running kiosk to refresh."
fi

# The EXIT trap deletes $TMP — the downloaded zip + everything that
# was in it except the media we just moved into PROJECT_DIR.
