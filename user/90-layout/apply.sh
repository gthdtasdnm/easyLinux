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
# Angeheftete Apps im Startmenü wie bei Windows – nur bei der Ersteinrichtung, eigene Favoriten bleiben
# bei Updates unangetastet. Kickoff speichert Favoriten im Aktivitäten-Dienst, nicht in einer Datei.
if $reset; then
    fav() { qdbus6 org.kde.ActivityManager /ActivityManager/Resources/Linking \
        "org.kde.ActivityManager.ResourcesLinking.$1" org.kde.plasma.favorites.applications "$2" :global >/dev/null 2>&1 || true; }
    fav UnlinkResourceFromActivity applications:systemsettings.desktop
    for app in easylinux-settings org.kde.dolphin easylinux-photos easylinux-mediaplayer org.kde.kcalc cachyos-pi; do
        if [ -e "/usr/share/applications/$app.desktop" ]; then fav LinkResourceToActivity "applications:$app.desktop"; fi
    done
fi
ok "Taskleiste und Startmenü eingerichtet"
