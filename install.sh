#!/usr/bin/env bash
# easyLinux installieren. Läuft ohne Rückfragen; die vorherigen Einstellungen werden
# gesichert und können mit ./uninstall.sh wiederhergestellt werden.
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
. "$repo/lib/common.sh"

require_user_session
mkdir -p "$EASYLINUX_STATE"
info "Für systemweite Teile wird einmal das Passwort benötigt."
root true

info "easyLinux wird eingerichtet …"
for module in "$repo"/modules/*/apply.sh; do
    bash "$module" || warn "Schritt fehlgeschlagen: $(basename "$(dirname "$module")")"
done

date -Iseconds > "$EASYLINUX_STATE/installed"
ok "Fertig. Rückgängig machen mit ./uninstall.sh"
info "Bitte einmal ab- und wieder anmelden, damit Strg+Alt+Entf und Strg+Umschalt+Esc aktiv werden."
