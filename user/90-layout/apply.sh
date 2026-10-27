#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Taskleiste und Startmenü wie bei Windows.
backup_config plasma-org.kde.plasma.desktop-appletsrc
backup_config plasmashellrc
plasma_running || { warn "Plasma läuft nicht – Taskleiste wird beim nächsten Anmelden eingerichtet."; exit 1; }
plasma_eval "$here/layout.js" >/dev/null
ok "Taskleiste und Startmenü eingerichtet"
