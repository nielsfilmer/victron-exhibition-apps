#!/usr/bin/env bash
# One-shot installer that templates __PROJECT_DIR__ into the LaunchAgent plists,
# copies them to ~/Library/LaunchAgents, and loads the chosen one.
#
# Usage:
#   ./kiosk/install.sh app1     # install + load App 1 LaunchAgent
#   ./kiosk/install.sh app2     # install + load App 2 LaunchAgent
#   ./kiosk/install.sh uninstall app1
#   ./kiosk/install.sh uninstall app2
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$AGENT_DIR"

# macOS TCC protects these user folders. LaunchAgents invoked by /bin/bash
# can't read scripts living under them — the script silently fails with
# "Operation not permitted" and the kiosk never starts. Refuse install up
# front and tell the operator how to fix.
refuse_if_protected_path() {
  local p="$PROJECT_DIR"
  local protected_dirs=(
    "$HOME/Documents"
    "$HOME/Desktop"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
  )
  for prefix in "${protected_dirs[@]}"; do
    if [[ "$p" == "$prefix" || "$p" == "$prefix/"* ]]; then
      cat >&2 <<EOF
✖ Refusing to install: project lives in a TCC-protected folder.

  Project path:  $p
  Protected by:  macOS TCC ($prefix)

  When the LaunchAgent runs at boot, /bin/bash can't read scripts from
  ~/Documents, ~/Desktop, ~/Downloads, ~/Pictures, ~/Movies, or ~/Music.
  The agent fails silently with "Operation not permitted" and the kiosk
  never starts.

  Fix — move the project out, then re-run install from the new location:

    mv "$p" "$HOME/$(basename "$p")"
    cd "$HOME/$(basename "$p")"
    ./kiosk/install.sh ${1:-app1}

EOF
      exit 1
    fi
  done
}

install_one() {
  local which="$1"
  local label="com.intersolar.$which"
  local src="$PROJECT_DIR/kiosk/$label.plist"
  local dst="$AGENT_DIR/$label.plist"

  if [[ ! -f "$src" ]]; then echo "Missing $src" >&2; exit 1; fi

  refuse_if_protected_path "$which"

  /usr/bin/sed "s|__PROJECT_DIR__|$PROJECT_DIR|g" "$src" > "$dst"
  chmod +x "$PROJECT_DIR/kiosk/launch-$which.sh"

  launchctl unload "$dst" 2>/dev/null || true
  launchctl load -w "$dst"
  echo "Installed and loaded $label."
  echo "Start now:   launchctl start $label"
  echo "Logs:        $PROJECT_DIR/kiosk/$which.out.log / $which.err.log"
}

uninstall_one() {
  local which="$1"
  local label="com.intersolar.$which"
  local dst="$AGENT_DIR/$label.plist"
  launchctl unload "$dst" 2>/dev/null || true
  rm -f "$dst"
  echo "Removed $label."
}

case "${1:-}" in
  app1|app2)              install_one "$1" ;;
  uninstall)              uninstall_one "${2:?usage: uninstall app1|app2}" ;;
  *) echo "Usage: $0 {app1|app2|uninstall app1|uninstall app2}" >&2; exit 1 ;;
esac
