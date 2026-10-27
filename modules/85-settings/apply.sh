#!/usr/bin/env bash
# Einstellungen wie bei Windows 11: ein Fenster, deutsche Suche, „Installierte Apps“.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Kleine C++-Brücke, damit die KDE-Einstellungsseiten im selben Fenster erscheinen.
# Schlägt das Bauen fehl, öffnen sich die Seiten wie bisher in eigenen Fenstern.
pkg_need gcc pkgconf
if root sh "$EASYLINUX_OPT/apps/settings/kcmhost/build.sh" >/dev/null 2>&1; then
    ok "Einstellungsseiten werden im selben Fenster angezeigt"
else
    warn "Einstellungsseiten öffnen sich in eigenen Fenstern (Brücke konnte nicht gebaut werden)"
fi
sys_put "$here/easylinux-settings.desktop" /usr/local/share/applications/easylinux-settings.desktop
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Einstellungen eingerichtet"
