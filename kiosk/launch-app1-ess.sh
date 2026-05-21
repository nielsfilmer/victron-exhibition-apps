#!/usr/bin/env bash
# Thin wrapper — launches App 1 with the ESS content version.
# All Chrome flags + caffeinate live in launch-app1.sh; this script
# only selects which version to load. See launch-app1.sh for the full
# flag set and the per-version Chrome profile path.
#
# Installed by ./kiosk/install.sh app1-ess (or by double-clicking
# "Install App 1 - ESS.command" in the project root). The matching
# LaunchAgent label is com.intersolar.app1-ess.
exec "$(cd "$(dirname "$0")" && pwd)/launch-app1.sh" ess
