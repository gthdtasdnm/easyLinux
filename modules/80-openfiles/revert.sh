#!/usr/bin/env bash
# Flatpak und fuse2 nur entfernen, wenn nichts mehr davon abhängt – sonst würden über easyLinux
# installierte Flatpak-Apps bzw. AppImages nach dem Deinstallieren nicht mehr starten.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"
pkgs="$EASYLINUX_SYS/packages.txt"

if root grep -qx flatpak "$pkgs" 2>/dev/null; then
    if [ -n "$(flatpak list --app --columns=application 2>/dev/null)" ]; then
        warn "Flatpak bleibt installiert, weil Flatpak-Apps installiert sind."
        root sed -i '/^flatpak$/d' "$pkgs"
    else
        # Nur von Plasma angelegte Ausnahmen für Browser und die leere Ablage – keine Apps
        rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak"
    fi
fi
if root grep -qx fuse2 "$pkgs" 2>/dev/null && ls "$HOME"/Programme/*.[Aa]pp[Ii]mage >/dev/null 2>&1; then
    warn "fuse2 bleibt installiert, weil AppImage-Programme in ~/Programme liegen."
    root sed -i '/^fuse2$/d' "$pkgs"
fi
true
