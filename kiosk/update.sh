#!/usr/bin/env bash
# Pull the latest version of the kiosk apps from GitHub and reload any
# loaded LaunchAgents so the running kiosk picks up the changes.
#
# Usage:
#   ./kiosk/update.sh
#
# Safe-fail behaviour:
#   - Bails if not inside a git repo (e.g. project was originally
#     downloaded as a zip rather than cloned).
#   - Bails if there are local uncommitted changes (so we never
#     clobber on-site edits).
#   - Bails if the current branch isn't `main`.
#   - Uses `--ff-only` so we never accidentally merge.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

# 1. Sanity: is this a git repo?
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  red "✖ $PROJECT_DIR is not a git repo."
  echo "  This script only works on installs cloned from GitHub."
  echo "  To fix: re-install with"
  echo "    git clone https://github.com/nielsfilmer/victron-exhibition-apps.git"
  exit 1
fi

# 2. Sanity: no local changes (would be clobbered by a hard reset, or
# would block the fast-forward pull).
if ! git diff --quiet || ! git diff --cached --quiet; then
  red "✖ Local uncommitted changes detected:"
  git status --short
  echo
  echo "  Stash, commit, or discard them before updating:"
  echo "    git stash               # set them aside"
  echo "    git checkout -- .       # discard them (DESTRUCTIVE)"
  exit 1
fi

# 3. Sanity: on the main branch.
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo 'detached')"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  red "✖ Currently on branch '$CURRENT_BRANCH', expected 'main'."
  echo "  Switch with:  git checkout main"
  exit 1
fi

# 4. Capture pre-update SHA so we can show what changed.
OLD_SHA="$(git rev-parse HEAD)"

# 5. Pull latest.
yellow "→ Fetching latest from origin/main…"
git fetch --quiet origin main
if ! git pull --ff-only --quiet origin main; then
  red "✖ Pull failed (likely a non-fast-forward / divergent history)."
  echo "  Investigate manually with: git log HEAD..origin/main"
  exit 1
fi

NEW_SHA="$(git rev-parse HEAD)"
if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
  green "✓ Already up to date ($(git rev-parse --short HEAD))."
  exit 0
fi

green "✓ Updated $(git rev-parse --short "$OLD_SHA") → $(git rev-parse --short "$NEW_SHA")."
echo
yellow "→ New commits in this update:"
git log --oneline "$OLD_SHA..$NEW_SHA"
echo

# 6. Restart any loaded kiosk LaunchAgents so the running kiosk picks
# up the new files. install.sh already used absolute paths via the
# templated plist, so no re-template is needed unless the project
# folder moved (which this script can't help with anyway).
#
# Use `launchctl kickstart -k` — it explicitly KILLs the running
# process before restarting. The older unload + load sequence doesn't
# reliably kill the existing Chrome instance (Chrome doesn't always
# react to SIGTERM in --kiosk mode), so the user ends up still
# looking at the pre-update version even though the files on disk
# changed. kickstart -k is bullet-proof.
RELOADED=0
UID_NUM="$(id -u)"
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
    yellow "→ Restarting $label (killing + re-launching kiosk Chrome)…"
    launchctl kickstart -k "gui/$UID_NUM/$label"
    RELOADED=$((RELOADED + 1))
  fi
done

if [[ "$RELOADED" -eq 0 ]]; then
  yellow "→ No kiosk LaunchAgent is currently loaded."
  echo "  Run ./kiosk/install.sh app1-ess (or app1-ol/app1-microgrid/app2/app3) to install + start one."
else
  green "✓ Restarted $RELOADED kiosk LaunchAgent(s) — kiosk is back up with the new files."
fi
