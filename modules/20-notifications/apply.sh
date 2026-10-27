#!/usr/bin/env bash
# Benachrichtigungen wie bei Windows: Popups verschwinden nach ein paar Sekunden
# und bleiben im Benachrichtigungscenter (Verlauf) erhalten.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

backup_config plasmanotifyrc

kwriteconfig6 --file plasmanotifyrc --group Notifications --key PopupTimeout 6000
kwriteconfig6 --file plasmanotifyrc --group Notifications --key LowPriorityHistory true
# Hinweis: Meldungen, die eine App ausdrücklich als "dauerhaft" schickt, ignorieren
# PopupTimeout noch. Dafür braucht es später eine eigene Lösung (siehe README, Punkt 9).

ok "Benachrichtigungen verschwinden nach 6 Sekunden und landen im Verlauf"
