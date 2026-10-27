#!/usr/bin/env bash
# Ein Design für alles: Flatpak-Apps (GTK und Qt) übernehmen Farben, Schrift und Hell/Dunkel des Systems.
# Die GTK-Einstellungen selbst schreibt KDE bereits passend (Breeze); hier bekommen Flatpaks Lesezugriff darauf.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

pkg_need breeze-gtk xdg-desktop-portal-kde
if [ -e /var/lib/flatpak/overrides/global ]; then
    warn "Es gibt bereits globale Flatpak-Einstellungen – werden nicht überschrieben."
else
    sys_put "$here/flatpak-overrides" /var/lib/flatpak/overrides/global
fi
ok "Einheitliches Design auch für Flatpak-Apps"
