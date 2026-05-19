#!/usr/bin/env bash
# Regenerate the .docx user manual from kiosk/INSTALL.md and drop it
# into ~/Downloads/. Run this on the dev machine whenever INSTALL.md
# changes; upload the result to Google Drive to refresh the Google Doc.
#
# Deps are local to kiosk/build-docx/ (declared in package.json) — the
# first run does `npm install` into kiosk/build-docx/node_modules/
# (gitignored). Subsequent runs are fast. No global npm installs.
#
# Not run by the kiosk itself; never installed as a LaunchAgent.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$PROJECT_DIR/kiosk/build-docx"

if ! command -v node >/dev/null 2>&1; then
  echo "✖ node is not on \$PATH. Install Node.js (https://nodejs.org/) and re-run." >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "✖ npm is not on \$PATH (usually shipped with Node.js)." >&2
  exit 1
fi

cd "$DIR"

# First run on a fresh clone: install the locked deps. Subsequent runs
# skip this if node_modules already exists. Use `npm ci` when a
# package-lock.json is present (reproducible, no version drift); fall
# back to `npm install` if not.
if [[ ! -d node_modules ]]; then
  echo "→ First run: installing deps into $DIR/node_modules/"
  if [[ -f package-lock.json ]]; then
    npm ci --silent
  else
    npm install --silent
  fi
fi

node build.js
