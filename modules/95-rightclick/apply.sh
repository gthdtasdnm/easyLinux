#!/usr/bin/env bash
# Rechtsklick wie bei Windows: Startknopf → Win+X-Menü, Taskleiste → Task-Manager und Taskleisteneinstellungen.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

pkg_need gcc pkgconf
src="$EASYLINUX_OPT/apps/taskbarmenu"
if ! root sh "$src/build.sh" >/dev/null 2>&1; then
    warn "Rechtsklickmenü konnte nicht gebaut werden – es bleibt beim Plasma-Menü."
    exit 0
fi
sys_put "$src/org.easylinux.taskbarmenu.so" /usr/lib/qt6/plugins/plasma/containmentactions/org.easylinux.taskbarmenu.so 755
# Nach Qt-/Plasma-Updates beide C++-Teile (auch die Einstellungen-Brücke) automatisch neu bauen
sys_put "$here/easylinux-rebuild.hook" /etc/pacman.d/hooks/easylinux-rebuild.hook

# Leisten (Containment-Typ 1) bekommen das neue Menü; Plasma muss dafür kurz neu starten,
# sonst überschreibt es die Einstellung beim Beenden. (Gesichert wurde die Datei schon in 90-layout.)
backup_config plasma-org.kde.plasma.desktop-appletsrc
plasma_stop
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 1 \
    --key "RightButton;NoModifier" org.easylinux.taskbarmenu
plasma_start
ok "Rechtsklick auf Startknopf und Taskleiste wie bei Windows"
