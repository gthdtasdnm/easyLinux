#!/usr/bin/env bash
# Update-Manager: ein Klick, Fortschritt, Restzeit, Sicherheitsupdates hervorgehoben, sanfte Erinnerung.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

pkg_need arch-audit
root chmod 755 "$EASYLINUX_OPT/apps/updater/helper.py"
sys_put "$here/org.easylinux.update.policy" /usr/share/polkit-1/actions/org.easylinux.update.policy
sys_put "$here/49-easylinux-update.rules" /etc/polkit-1/rules.d/49-easylinux-update.rules
sys_put "$here/easylinux-updater.desktop" /usr/local/share/applications/easylinux-updater.desktop
sys_put "$here/easylinux-update-check.service" /etc/systemd/user/easylinux-update-check.service
sys_put "$here/easylinux-update-check.timer" /etc/systemd/user/easylinux-update-check.timer
user_unit_enable easylinux-update-check.timer >/dev/null 2>&1

# Das Update-Symbol von CachyOS im Systemabschnitt ausblenden – sonst doppelte Hinweise
if [ -f /etc/xdg/autostart/arch-update-tray.desktop ]; then
    backup_config autostart/arch-update-tray.desktop
    mkdir -p "$EASYLINUX_CONFIG/autostart"
    printf '[Desktop Entry]\nType=Application\nName=Arch-Update Tray\nHidden=true\n' \
        > "$EASYLINUX_CONFIG/autostart/arch-update-tray.desktop"
fi
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Update-Manager eingerichtet"
