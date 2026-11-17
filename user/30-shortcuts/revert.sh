#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"
shortcut="$EASYLINUX_OPT/bin/easylinux-shortcut"
"$shortcut" clear easylinux-sessionmenu.desktop _launch >/dev/null 2>&1
"$shortcut" clear easylinux-taskmanager.desktop _launch >/dev/null 2>&1
"$shortcut" set ksmserver "Log Out" Ctrl+Alt+Del >/dev/null 2>&1
"$shortcut" clear easylinux-settings.desktop _launch >/dev/null 2>&1
"$shortcut" clear easylinux-quickmenu.desktop _launch >/dev/null 2>&1
"$shortcut" launch systemsettings.desktop Systemeinstellungen Meta+I >/dev/null 2>&1
"$shortcut" set kwin "Walk Through Windows" Alt+Tab Meta+Tab >/dev/null 2>&1
"$shortcut" set kwin Overview Meta+W >/dev/null 2>&1
true
