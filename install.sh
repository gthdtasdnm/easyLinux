#!/usr/bin/env bash
# easyLinux installieren. Läuft ohne Rückfragen; die vorherigen Einstellungen werden
# gesichert und können mit ./uninstall.sh wiederhergestellt werden.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
. "$root/lib/common.sh"

require_user_session
mkdir -p "$EASYLINUX_STATE"

info "easyLinux wird eingerichtet …"
for module in "$root"/modules/*/apply.sh; do
    bash "$module" || warn "Schritt fehlgeschlagen: $(basename "$(dirname "$module")")"
done

date -Iseconds > "$EASYLINUX_STATE/installed"
ok "Fertig. Rückgängig machen mit ./uninstall.sh"
