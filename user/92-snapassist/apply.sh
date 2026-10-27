#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Andock-Assistent (Snap Assist) für diesen Benutzer einschalten und gleich laden.
backup_config kwinrc
kwriteconfig6 --file kwinrc --group Plugins --key easylinux-snapassistEnabled true
script=/usr/share/kwin/scripts/easylinux-snapassist/contents/ui/main.qml
if [ "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded easylinux-snapassist 2>/dev/null)" != true ]; then
    id="$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript "$script" easylinux-snapassist 2>/dev/null || true)"
    [ -n "$id" ] && qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1 || true
fi
ok "Andock-Assistent eingeschaltet"
