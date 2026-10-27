#!/usr/bin/env bash
# Snap Assist: nach dem Andocken an eine Bildschirmhälfte die anderen Fenster für die freie Hälfte anbieten.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

dest=/usr/share/kwin/scripts/easylinux-snapassist
sys_put "$here/easylinux-snapassist/metadata.json" "$dest/metadata.json"
sys_put "$here/easylinux-snapassist/contents/ui/main.qml" "$dest/contents/ui/main.qml"
sys_put "$here/easylinux-snapassist/contents/ui/Picker.qml" "$dest/contents/ui/Picker.qml"

backup_config kwinrc
kwriteconfig6 --file kwinrc --group Plugins --key easylinux-snapassistEnabled true
# KWin kennt frisch installierte Skripte erst nach dem nächsten Anmelden – deshalb gleich laden
if [ "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded easylinux-snapassist 2>/dev/null)" != true ]; then
    id="$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript "$dest/contents/ui/main.qml" easylinux-snapassist 2>/dev/null || true)"
    [ -n "$id" ] && qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1 || true
fi
ok "Andock-Assistent eingerichtet (Fenster an den Rand ziehen oder Meta+←/→)"
