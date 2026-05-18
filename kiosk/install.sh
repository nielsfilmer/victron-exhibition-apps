#!/usr/bin/env bash
# One-shot installer that templates __PROJECT_DIR__ into the LaunchAgent plists,
# copies them to ~/Library/LaunchAgents, and loads the chosen one(s).
#
# Usage:
#   ./kiosk/install.sh app1     # install + load App 1 LaunchAgent
#   ./kiosk/install.sh app2     # install + load App 2 LaunchAgent
#   ./kiosk/install.sh app3     # install + load the 4 App 3 LaunchAgents
#                               # (ws relay + center + left + right)
#   ./kiosk/install.sh uninstall app1
#   ./kiosk/install.sh uninstall app2
#   ./kiosk/install.sh uninstall app3
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$AGENT_DIR"

# App 3 installs four LaunchAgents that share a common prefix. List them
# in startup order: the ws relay is harmless to start last (the kiosks
# auto-reconnect with backoff), but starting it first means satellites
# pick up the cached state without a visible reconnect delay.
APP3_LABELS=(
  com.intersolar.app3-ws
  com.intersolar.app3-center
  com.intersolar.app3-left
  com.intersolar.app3-right
)

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

# Install a single LaunchAgent by label. The plist source lives at
# kiosk/<label>.plist; the matching launch script lives at
# kiosk/launch-<label-suffix>.sh (where the suffix is everything after
# "com.intersolar."). Both must exist; if either is missing this bails.
install_label() {
  local label="$1"
  local suffix="${label#com.intersolar.}"
  local src="$PROJECT_DIR/kiosk/$label.plist"
  local dst="$AGENT_DIR/$label.plist"
  local script="$PROJECT_DIR/kiosk/launch-$suffix.sh"

  if [[ ! -f "$src" ]]; then echo "Missing $src" >&2; exit 1; fi
  if [[ ! -f "$script" ]]; then echo "Missing $script" >&2; exit 1; fi

  /usr/bin/sed "s|__PROJECT_DIR__|$PROJECT_DIR|g" "$src" > "$dst"
  chmod +x "$script"

  launchctl unload "$dst" 2>/dev/null || true
  launchctl load -w "$dst"
  echo "Installed and loaded $label."
}

uninstall_label() {
  local label="$1"
  local dst="$AGENT_DIR/$label.plist"
  launchctl unload "$dst" 2>/dev/null || true
  rm -f "$dst"
  echo "Removed $label."
}

install_app1() {
  refuse_if_protected_path app1
  install_label "com.intersolar.app1"
  echo "Start now:   launchctl start com.intersolar.app1"
  echo "Logs:        $PROJECT_DIR/kiosk/app1.out.log / app1.err.log"
}

install_app2() {
  refuse_if_protected_path app2
  install_label "com.intersolar.app2"
  echo "Start now:   launchctl start com.intersolar.app2"
  echo "Logs:        $PROJECT_DIR/kiosk/app2.out.log / app2.err.log"
}

install_app3() {
  refuse_if_protected_path app3
  # App 3 needs the prebuilt relay binary for this Mac's CPU. The
  # kiosk JS auto-reconnects so this isn't strictly fatal, but
  # without it the slideshow will never sync — better to fail fast.
  local arch="$(uname -m)"
  local relay="$PROJECT_DIR/kiosk/bin/kiosk-ws-relay-$arch"
  if [[ ! -x "$relay" ]]; then
    echo "✖ Missing relay binary for this CPU ($arch): $relay" >&2
    echo "  Rebuild with: cd kiosk/ws-relay && ./build.sh" >&2
    exit 1
  fi
  # Trap partial installs — `set -euo pipefail` makes any
  # `install_label` failure terminate the script, which would leave
  # whatever previous labels succeeded loaded as LaunchAgents. Tell
  # the operator how to clean up, rather than dying silently.
  local installed=()
  trap '
    if [[ ${#installed[@]} -gt 0 && ${#installed[@]} -lt ${#APP3_LABELS[@]} ]]; then
      echo "" >&2
      echo "✖ Partial install: ${#installed[@]} of ${#APP3_LABELS[@]} App 3 LaunchAgents loaded." >&2
      echo "  Installed: ${installed[*]}" >&2
      echo "  Run \"./kiosk/install.sh uninstall app3\" to remove the partial install," >&2
      echo "  fix the error above, then re-run \"./kiosk/install.sh app3\"." >&2
    fi
  ' EXIT
  for label in "${APP3_LABELS[@]}"; do
    install_label "$label"
    installed+=("$label")
  done
  trap - EXIT
  echo
  echo "App 3 installed (4 LaunchAgents)."
  echo "Logs:        $PROJECT_DIR/kiosk/app3-{ws,center,left,right}.{out,err}.log"
  echo "Display geometry: kiosk/app3-displays.env (edit if your"
  echo "                  displays aren't 3× 1920×1080 in a row)."
}

uninstall_one() {
  case "$1" in
    app1|app2) uninstall_label "com.intersolar.$1" ;;
    app3)
      for label in "${APP3_LABELS[@]}"; do
        uninstall_label "$label"
      done ;;
    *) echo "Usage: $0 uninstall {app1|app2|app3}" >&2; exit 1 ;;
  esac
}

case "${1:-}" in
  app1) install_app1 ;;
  app2) install_app2 ;;
  app3) install_app3 ;;
  uninstall) uninstall_one "${2:?usage: uninstall app1|app2|app3}" ;;
  *) echo "Usage: $0 {app1|app2|app3|uninstall {app1|app2|app3}}" >&2; exit 1 ;;
esac
