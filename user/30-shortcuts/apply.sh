#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Tastenkürzel: Strg+Umschalt+Esc → Taskmanager, Strg+Alt+Entf → Windows-Bildschirm (statt „Abmelden“).
shortcut="$EASYLINUX_OPT/bin/easylinux-shortcut"
"$shortcut" launch easylinux-taskmanager.desktop Taskmanager Ctrl+Shift+Esc >/dev/null
"$shortcut" clear ksmserver "Log Out" >/dev/null
"$shortcut" launch easylinux-sessionmenu.desktop Sicherheitsoptionen Ctrl+Alt+Del >/dev/null
ok "Tastenkürzel eingerichtet"
