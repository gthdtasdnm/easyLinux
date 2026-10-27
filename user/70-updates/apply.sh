#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Das Update-Symbol von CachyOS ausblenden – sonst gäbe es zwei Update-Hinweise.
if [ -f /etc/xdg/autostart/arch-update-tray.desktop ]; then
    backup_config autostart/arch-update-tray.desktop
    mkdir -p "$EASYLINUX_CONFIG/autostart"
    printf '[Desktop Entry]\nType=Application\nName=Arch-Update Tray\nHidden=true\n' \
        > "$EASYLINUX_CONFIG/autostart/arch-update-tray.desktop"
fi
ok "Update-Hinweise vereinheitlicht"
