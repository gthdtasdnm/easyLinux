#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Taskleiste und Startmenü wie bei Windows, auf jedem Bildschirm.
# Nur bei der Ersteinrichtung wird die Hauptleiste neu angelegt. Danach (Update der Einrichtung,
# neuer Bildschirm) werden nur fehlende Leisten ergänzt – angeheftete Apps bleiben erhalten.
backup_config plasma-org.kde.plasma.desktop-appletsrc
backup_config plasmashellrc
plasma_running || { warn "Plasma läuft nicht – Taskleiste wird beim nächsten Anmelden eingerichtet."; exit 1; }
reset=true
[ -e "$EASYLINUX_STATE/user-setup-version" ] && reset=false
[ "${1:-}" = --reset ] && reset=true
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "var RESET = $reset; $(cat "$here/layout.js")" >/dev/null
ok "Taskleiste und Startmenü eingerichtet"
