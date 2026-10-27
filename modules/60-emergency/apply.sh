#!/usr/bin/env bash
# Notfall-Dienst: Strg+Alt+Entf hilft auch, wenn die Oberfläche komplett hängt.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

sys_put "$here/easylinux-emergency.service" /etc/systemd/system/easylinux-emergency.service
# Auf Textkonsolen startet Strg+Alt+Entf sonst sofort neu – das übernimmt jetzt das Notfall-Menü.
if [ "$(systemctl is-enabled ctrl-alt-del.target 2>/dev/null)" != masked ]; then
    root systemctl mask ctrl-alt-del.target >/dev/null 2>&1
    _sys_log masked.txt ctrl-alt-del.target
fi
unit_enable easylinux-emergency.service >/dev/null 2>&1
ok "Notfall-Dienst eingerichtet (Strg+Alt+Entf, wenn nichts mehr reagiert)"
