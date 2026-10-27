#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Benachrichtigungen wie bei Windows: nach 6 Sekunden ausblenden, im Verlauf behalten.
backup_config plasmanotifyrc
kwriteconfig6 --file plasmanotifyrc --group Notifications --key PopupTimeout 6000
kwriteconfig6 --file plasmanotifyrc --group Notifications --key LowPriorityHistory true
ok "Benachrichtigungen eingerichtet"
