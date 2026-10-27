#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"
shortcut="$here/../../bin/easylinux-shortcut"
"$shortcut" clear easylinux-sessionmenu.desktop _launch >/dev/null 2>&1
"$shortcut" clear easylinux-taskmanager.desktop _launch >/dev/null 2>&1
"$shortcut" set ksmserver "Log Out" Ctrl+Alt+Del >/dev/null 2>&1
true
