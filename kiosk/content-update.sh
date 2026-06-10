#!/usr/bin/env bash
# Fetch the latest media package from the content team's hosting and
# replace the kiosk apps' media/ folders + config.js files with the
# new content.
#
# Usage:
#   ./kiosk/content-update.sh            # download + apply, then auto-delete temp
#   ./kiosk/content-update.sh --keep     # same, but DON'T delete the temp dir —
#                                        # leaves the downloaded zip + extracted
#                                        # files on disk and prints the path so
#                                        # you can inspect them. --debug is an alias.
#
# Workflow:
#   1. Read the zip URL from kiosk/content-url.txt
#   2. Download to a temp dir
#   3. Unzip
#   4. For each target (App 1 has three version subfolders —
#      app1-slideshow/versions/{ess,ol,microgrid} — plus app2-chapters
#      and app3-multi-screen):
#        - replace local media/ from the zip's <target>/media/ if present
#        - replace local config.js from the zip's <target>/config.js if present
#      Either or both may be omitted from the zip per target — anything
#      missing is left untouched on disk.
#   5. Delete the temp dir + everything else from the zip
#   6. Restart any loaded kiosk LaunchAgent so the running kiosk picks
#      up the new files
#
# Notes:
#   - Only media/ folders and config.js files are touched. HTML, CSS,
#     fonts, launch scripts, plists, the ws-relay binary, and
#     app3-displays.env (operator-edited per-Mac hardware geometry)
#     are NEVER touched by this script — those belong to dev / ops.
#   - The config.js update path lets the content team ship new slide
#     copy / hotspot coordinates / left/middle/right mappings
#     alongside new media without a code change. The risk is real
#     though: a malformed config.js will fail to load and the kiosk
#     will show its on-screen error overlay. Recovery below.
#   - To restore the original committed media + config (if a content
#     update went wrong), run:
#       git checkout -- app1-slideshow/versions/ \
#                       app2-chapters/{media,config.js} \
#                       app3-multi-screen/{media,config.js}
#     (app1-slideshow/versions/ covers all three version subfolders;
#     everything else under app1-slideshow/ — index.html, fonts/ — is
#     out of the content-team scope and is never modified by this script.)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$PROJECT_DIR/kiosk/content-url.txt"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# 0. Parse options. --keep / --debug preserves the temp dir (downloaded zip +
#    extracted files) for inspection instead of deleting it on exit.
KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep|--debug) KEEP=1 ;;
    -h|--help)
      echo "Usage: $0 [--keep|--debug]"
      echo "  --keep / --debug   keep the temp dir (zip + extracted files) and print its path"
      exit 0 ;;
    *)
      red "✖ Unknown option: $1"
      echo "  Usage: $0 [--keep|--debug]"
      exit 1 ;;
  esac
  shift
done

# Temp-dir cleanup. Wired to the EXIT trap below (after $TMP exists). With
# --keep we leave it in place and tell the operator where to find it / how to
# remove it; otherwise it's deleted on every exit, success or failure.
cleanup() {
  if [[ "$KEEP" -eq 1 ]]; then
    echo
    yellow "→ --keep: temp dir left in place for inspection:"
    echo "    dir : $TMP"
    echo "    zip : $TMP/content.zip"
    echo "    ext : $TMP/unzipped/"
    echo "    Remove it when done:  rm -rf \"$TMP\""
  else
    rm -rf "$TMP"
  fi
}

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

# 3. Make a temp dir + clean on exit (unless --keep — see cleanup()).
TMP="$(mktemp -d -t content-update.XXXXXX)"
trap cleanup EXIT
[[ "$KEEP" -eq 1 ]] && yellow "→ --keep set: temp dir will be preserved at $TMP"

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

# 4. Unzip.
#    unzip exit codes: 0 = clean, 1 = minor warnings, 2 = a zipfile-format
#    quirk it worked around — ALL THREE still extract the files. Only codes
#    >= 3 are genuine failures. We must distinguish these: a Dropbox "download
#    folder as zip" archive carries a spurious top-level "/" entry, which makes
#    unzip strip it ("stripped absolute path spec from /") and return exit 2
#    even though every real file extracted. Treating any non-zero as fatal (the
#    old `if ! unzip`) rejected those perfectly-good Dropbox zips.
yellow "→ Extracting…"
mkdir -p "$TMP/unzipped"
unzip_rc=0
unzip -q "$ZIP" -d "$TMP/unzipped" || unzip_rc=$?
if [[ "$unzip_rc" -gt 2 ]]; then
  red "✖ Extraction failed — the downloaded file may not be a valid zip (unzip exit $unzip_rc)."
  exit 1
fi
if [[ "$unzip_rc" -ne 0 ]]; then
  yellow "  (unzip exit $unzip_rc — non-fatal warnings, e.g. a stray top-level"
  yellow "   entry in a Dropbox folder zip; the files extracted fine. Continuing.)"
fi

# 5. Locate a given path inside the extracted tree. Accepts either flat
#    layout (app1-slideshow/media/) or nested one level deep under a
#    single top-level folder (foo/app1-slideshow/media/). Works for
#    both files (config.js) and directories (media/) — the caller
#    decides which by passing -d / -f to the existence test.
find_in_zip() {
  local app="$1"
  local sub="$2"      # "media" or "config.js"
  local test_flag="$3" # "-d" or "-f"
  local cand
  for cand in \
      "$TMP/unzipped/$app/$sub" \
      "$TMP"/unzipped/*/"$app"/"$sub"; do
    # `test` (not `[[ ]]`) so the operator flag can come from a
    # variable — bash parses `[[ ]]` operators at parse time, not
    # at evaluation time, so `[[ $flag $path ]]` is a syntax error.
    if test "$test_flag" "$cand"; then echo "$cand"; return 0; fi
  done
  return 1
}

# 6. Replace local media/ + config.js per target — each is independent;
#    a zip may include either, both, or neither for any given target.
#    Anything missing from the zip is left untouched on disk (matches
#    the existing media-only behaviour the content team is used to).
#    App 1 has three version subfolders under app1-slideshow/versions/,
#    each treated as its own target (the find_in_zip helper resolves
#    arbitrarily-deep paths, so no special-casing here).
APPS=(
  app1-slideshow/versions/ess
  app1-slideshow/versions/ol
  app1-slideshow/versions/microgrid
  app2-chapters
  app3-multi-screen
)
REPLACED_MEDIA=0
REPLACED_CONFIG=0
TOUCHED_APPS=()
for app in "${APPS[@]}"; do
  # `declare` makes the per-iteration scope explicit. (`local` is
  # function-scope only — this loop is at script top level, so
  # `app_touched` is technically a global. The reset at the top of
  # each iteration prevents cross-app contamination.)
  declare app_touched=0

  if SRC="$(find_in_zip "$app" "media" -d)"; then
    DEST="$PROJECT_DIR/$app/media"
    yellow "→ Replacing $app/media (from $SRC)…"
    rm -rf "$DEST"
    mkdir -p "$DEST"
    # Copy contents (the dot-slash form preserves dotfiles + avoids
    # nesting the source folder name).
    cp -R "$SRC"/. "$DEST"/
    touch "$DEST/.gitkeep"   # keep the tracked folder marker after a content drop
    REPLACED_MEDIA=$((REPLACED_MEDIA + 1))
    app_touched=1
  fi

  if SRC="$(find_in_zip "$app" "config.js" -f)"; then
    DEST="$PROJECT_DIR/$app/config.js"
    yellow "→ Replacing $app/config.js (from $SRC)…"
    cp "$SRC" "$DEST"
    REPLACED_CONFIG=$((REPLACED_CONFIG + 1))
    app_touched=1
  fi

  if [[ $app_touched -eq 1 ]]; then
    TOUCHED_APPS+=("$app")
  fi
done

if [[ $((REPLACED_MEDIA + REPLACED_CONFIG)) -eq 0 ]]; then
  red "✖ Nothing was replaced — the zip's layout doesn't match the"
  echo "  expected structure (no media/ folders and no config.js files"
  echo "  were found at any of: app1-slideshow/versions/{ess,ol,microgrid}/,"
  echo "  app2-chapters/, app3-multi-screen/). See"
  echo "  kiosk/content-url.txt for the layout the script expects."
  exit 1
fi

green "✓ Replaced $REPLACED_MEDIA media folder(s) + $REPLACED_CONFIG config file(s)."
# Tell the operator which apps were actually touched — most relevant
# for them to know which kiosk to keep an eye on after the restart.
# TOUCHED_APPS is guaranteed non-empty here: the (REPLACED_MEDIA +
# REPLACED_CONFIG == 0) early-exit above means at least one app
# contributed to the counts, and the only way to contribute is via
# the `app_touched=1` branches in the per-app loop above (which
# always append the app to TOUCHED_APPS). Important for macOS bash
# 3.2 + `set -u`, where expanding an empty array crashes — if you
# move this block, re-check the precondition.
if [[ "${#TOUCHED_APPS[@]}" -gt 0 ]]; then
  yellow "  Apps updated: ${TOUCHED_APPS[*]}"
fi
SKIPPED=()
for app in "${APPS[@]}"; do
  found=0
  for t in "${TOUCHED_APPS[@]}"; do
    [[ "$t" == "$app" ]] && { found=1; break; }
  done
  [[ $found -eq 0 ]] && SKIPPED+=("$app")
done
if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
  yellow "  (Nothing in zip for: ${SKIPPED[*]} — left untouched.)"
fi

# 7. Restart any loaded kiosk LaunchAgent so the kiosk picks up the
#    new media. Same kickstart approach as kiosk/update.sh — kills the
#    running Chrome and re-launches.
UID_NUM="$(id -u)"
RELOADED=0
KIOSK_LABELS=(
  com.intersolar.app1-ess
  com.intersolar.app1-ol
  com.intersolar.app1-microgrid
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
  green "✓ Kiosk restarted with the new content. (Brief black screen during restart.)"
else
  yellow "→ No kiosk LaunchAgent is currently loaded — files replaced on disk,"
  echo "  but no running kiosk to refresh."
fi

# The EXIT trap runs cleanup(): it deletes $TMP — the downloaded zip +
# everything that was in it except the media + config.js files we copied into
# PROJECT_DIR — UNLESS --keep was passed, in which case it's left in place and
# its path is printed for inspection.
