#!/usr/bin/env bash
# easyLinux entfernen und die Einstellungen von vor der Installation wiederherstellen.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
. "$root/lib/common.sh"

require_user_session
[ -f "$EASYLINUX_BACKUP/files.txt" ] || fail "Keine Sicherung gefunden – easyLinux scheint nicht installiert zu sein."

info "Vorherige Einstellungen werden wiederhergestellt …"
was_running=false
plasma_running && was_running=true
plasma_stop
restore_configs
$was_running && plasma_start

rm -rf "$EASYLINUX_STATE"
ok "easyLinux wurde entfernt."
