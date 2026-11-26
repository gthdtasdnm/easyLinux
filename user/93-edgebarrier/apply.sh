#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Maus läuft frei zwischen Bildschirmen; nur beim Fensterziehen bleibt sie am Rand hängen (KWin-Skript schaltet um).
backup_config kwinrc
kwriteconfig6 --file kwinrc --group EdgeBarrier --key EdgeBarrier 0
kwriteconfig6 --file kwinrc --group Plugins --key easylinux-edgebarrierEnabled true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
script=/usr/share/kwin/scripts/easylinux-edgebarrier/contents/code/main.js
if [ "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded easylinux-edgebarrier 2>/dev/null)" != true ]; then
    id="$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$script" easylinux-edgebarrier 2>/dev/null || true)"
    [ -n "$id" ] && qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1 || true
fi
ok "Bildschirmrand: Maus hängt nur beim Fensterziehen"
