#!/usr/bin/env bash
# easyLinux entfernen und die Einstellungen von vor der Installation wiederherstellen.
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
. "$repo/lib/common.sh"

require_user_session
[ -d "$EASYLINUX_STATE" ] || [ -d "$EASYLINUX_SYS" ] || fail "easyLinux scheint nicht installiert zu sein."

info "Vorherige Einstellungen werden wiederhergestellt …"
for revert in $(ls -r "$repo"/modules/*/revert.sh 2>/dev/null); do bash "$revert" || true; done
restore_user_units
was_running=false
plasma_running && was_running=true
plasma_stop
restore_configs
remove_user_files
$was_running && plasma_start
kbuildsycoca6 >/dev/null 2>&1 || true

info "Systemweite Änderungen werden entfernt …"
restore_system

rm -rf "$EASYLINUX_STATE"
ok "easyLinux wurde entfernt."
