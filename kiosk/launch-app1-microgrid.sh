#!/usr/bin/env bash
# Thin wrapper — launches App 1 with the Microgrid content version.
# All Chrome flags + caffeinate live in launch-app1.sh; this script
# only selects which version to load. See launch-app1.sh for the full
# flag set and the per-version Chrome profile path.
#
# Installed by ./kiosk/install.sh app1-microgrid (or by double-clicking
# "Install App 1 - Microgrid.command" in the project root). The matching
# LaunchAgent label is com.intersolar.app1-microgrid.
exec "$(cd "$(dirname "$0")" && pwd)/launch-app1.sh" microgrid
