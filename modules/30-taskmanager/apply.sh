#!/usr/bin/env bash
# Taskmanager (Strg+Umschalt+Esc) und Strg+Alt+Entf-Bildschirm.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

sys_put "$here/easylinux-taskmanager.desktop" /usr/local/share/applications/easylinux-taskmanager.desktop
sys_put "$here/easylinux-sessionmenu.desktop" /usr/local/share/applications/easylinux-sessionmenu.desktop
sys_put "$here/easylinux-taskmanager.service" /etc/systemd/user/easylinux-taskmanager.service
kbuildsycoca6 >/dev/null 2>&1 || true
user_unit_enable easylinux-taskmanager.service

shortcut="$EASYLINUX_OPT/bin/easylinux-shortcut"
"$shortcut" launch easylinux-taskmanager.desktop Taskmanager Ctrl+Shift+Esc >/dev/null
"$shortcut" clear ksmserver "Log Out" >/dev/null
"$shortcut" launch easylinux-sessionmenu.desktop Sicherheitsoptionen Ctrl+Alt+Del >/dev/null
ok "Taskmanager (Strg+Umschalt+Esc) und Strg+Alt+Entf eingerichtet"
