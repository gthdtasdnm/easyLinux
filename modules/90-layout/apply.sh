#!/usr/bin/env bash
# Richtet Taskleiste und Startmenü ein.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

backup_config plasma-org.kde.plasma.desktop-appletsrc
backup_config plasmashellrc

if ! plasma_running; then
    warn "Plasma läuft nicht – Taskleiste wird beim nächsten Anmelden nicht automatisch angepasst."
    exit 0
fi

plasma_eval "$here/layout.js" >/dev/null
ok "Taskleiste und Startmenü eingerichtet"
