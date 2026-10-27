#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Rechtsklick wie bei Windows: Leisten (Containment-Typ 1) bekommen das easyLinux-Menü.
# Plasma muss dafür kurz neu starten, sonst überschreibt es die Einstellung beim Beenden.
[ -e /usr/lib/qt6/plugins/plasma/containmentactions/org.easylinux.taskbarmenu.so ] || { warn "Rechtsklickmenü fehlt – übersprungen."; exit 0; }
backup_config plasma-org.kde.plasma.desktop-appletsrc
plasma_stop
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 1 \
    --key "RightButton;NoModifier" org.easylinux.taskbarmenu
plasma_start
ok "Rechtsklick auf Startknopf und Taskleiste wie bei Windows"
