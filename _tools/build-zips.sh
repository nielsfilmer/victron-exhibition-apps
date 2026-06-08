#!/usr/bin/env bash
# Build per-app installable zip bundles into dist/ — one per kiosk install.
#
#   dist/app1-ess.zip        dist/app1-ol.zip        dist/app1-microgrid.zip
#   dist/app2.zip            dist/app3.zip
#
# Each zip unpacks to a self-contained mini project root that an operator can
# install WITHOUT git: unzip it, then double-click the bundled
# "Install ….command". This is the artifact the CI workflow
# (.github/workflows/build-app-zips.yml) uploads to the GitHub Release on every
# push to main — but the script is also runnable by hand on a dev machine.
#
# Why a "bundle" and not just the app folder: the kiosk/ install scripts and
# LaunchAgent plists are what turn an app folder into an auto-booting kiosk, so
# each bundle ships the app's media + the kiosk/ machinery + the one Install
# command it needs. (App 3 additionally needs the prebuilt relay binary under
# kiosk/bin/, so only its bundle carries that ~10 MB payload.)
#
# Deliberately OMITTED from every bundle (they're git- or dev-only and would
# mislead a zip-installed operator):
#   - kiosk/update.sh + Update.command  → git-pull based; a zip install has no
#     git checkout. Updates come from downloading a newer zip.
#   - kiosk/ws-relay/ (Go source), kiosk/build-docx*, *.log
#                                        → developer tooling / runtime cruft.
# Kept on purpose: kiosk/content-update.sh + content-url.txt + Update
# media.command — content drops are git-independent and still work from a zip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

rm -rf "$DIST"
mkdir -p "$DIST"

# Build stamp baked into every bundle so an operator/dev can identify exactly
# which commit a zip came from (there's no git checkout inside the bundle).
SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Copy the kiosk/ machinery into a bundle, dropping dev-only / git-only bits.
#   $1 = bundle dir   $2 = "yes" to include kiosk/bin (App 3 relay), else "no"
copy_kiosk() {
  local dest="$1" with_bin="$2"
  cp -R kiosk "$dest/kiosk"
  rm -rf \
    "$dest/kiosk/update.sh" \
    "$dest/kiosk/build-docx.sh" \
    "$dest/kiosk/build-docx" \
    "$dest/kiosk/ws-relay"
  rm -f "$dest"/kiosk/*.log
  [[ "$with_bin" == "yes" ]] || rm -rf "$dest/kiosk/bin"
}

# Drop a short operator-facing READ ME and a machine-readable VERSION stamp at
# the bundle root, then zip the staging dir into dist/<name>.zip.
#   $1 = bundle name (= zip basename)   $2 = bundle dir   $3 = install command filename
finalize() {
  local name="$1" dir="$2" cmd="$3"
  printf 'app: %s\ncommit: %s\nbuilt: %s\n' "$name" "$SHA" "$DATE" > "$dir/VERSION.txt"
  cat > "$dir/READ ME FIRST.txt" <<EOF
Victron Exhibition Kiosk — $name
Built from commit $SHORT on $DATE

To install:
  1. Move this UNZIPPED folder somewhere under your home folder — e.g.
     /Users/<you>/$name. Do NOT leave it in Downloads, Documents, Desktop,
     Pictures, Movies, or Music: macOS blocks the kiosk auto-start from
     those folders (it will refuse the install and tell you so).
  2. Double-click "$cmd".
  3. Follow the prompt. Full operator manual: kiosk/INSTALL.md.

To update:
  Download the newer $name.zip from the project's GitHub Releases page and
  repeat the steps above. (These bundles update by re-downloading, not by
  "Update.command" — that one is only for git-based installs.)

Content-only refresh (new media / config, no code change):
  "Update media.command" pulls the latest content drop — see kiosk/INSTALL.md.
EOF
  ( cd "$STAGE" && zip -r -q -X "$DIST/$name.zip" "$name" -x '*.DS_Store' )
  printf '  → dist/%s.zip\n' "$name"
}

echo "Building app bundles (commit $SHORT) …"

# --- App 1: one bundle per content version, shipping only that version -------
# install.sh app1-<v> only references com.intersolar.app1-<v>.plist +
# launch-app1-<v>.sh, so a single-version app1-slideshow/ is sufficient.
declare -a A1=("ess:ESS" "ol:OL" "microgrid:Microgrid")
for pair in "${A1[@]}"; do
  v="${pair%%:*}"; label="${pair##*:}"
  name="app1-$v"
  d="$STAGE/$name"
  mkdir -p "$d/app1-slideshow/versions"
  cp app1-slideshow/index.html "$d/app1-slideshow/"
  cp -R app1-slideshow/fonts "$d/app1-slideshow/"
  cp -R "app1-slideshow/versions/$v" "$d/app1-slideshow/versions/"
  copy_kiosk "$d" no
  cmd="Install App 1 - $label.command"
  cp "$cmd" "$d/"
  cp "Update media.command" "$d/"
  finalize "$name" "$d" "$cmd"
done

# --- App 2 ------------------------------------------------------------------
d="$STAGE/app2"
mkdir -p "$d"
cp -R app2-chapters "$d/app2-chapters"
copy_kiosk "$d" no
cp "Install App 2.command" "$d/"
cp "Update media.command" "$d/"
finalize "app2" "$d" "Install App 2.command"

# --- App 3 (needs the relay binary under kiosk/bin) -------------------------
d="$STAGE/app3"
mkdir -p "$d"
cp -R app3-multi-screen "$d/app3-multi-screen"
copy_kiosk "$d" yes
cp "Install App 3.command" "$d/"
cp "Update media.command" "$d/"
finalize "app3" "$d" "Install App 3.command"

echo "Done. 5 bundles in dist/:"
ls -1sh "$DIST"
