#!/usr/bin/env bash
# Speicher-Wächter: Läuft der Arbeitsspeicher voll, beendet systemd-oomd die verursachende App
# nach 10 statt 30 Sekunden – bevor der Computer einfriert. Die Meldung dazu
# („Arbeitsspeicherengpass vermieden … Anwendung neu starten“) zeigt Plasma bereits selbst.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

sys_put "$here/oomd.conf" /etc/systemd/oomd.conf.d/easylinux.conf
sys_put "$here/user-slice.conf" /etc/systemd/system/user-.slice.d/easylinux-oomd.conf
root systemctl daemon-reload
root systemctl enable systemd-oomd.service >/dev/null 2>&1 || true
root systemctl restart systemd-oomd.service
ok "Speicher-Wächter eingerichtet"
