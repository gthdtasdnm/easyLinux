#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Tastenkürzel wie bei Windows: Strg+Umschalt+Esc → Taskmanager, Strg+Alt+Entf → Sicherheitsoptionen,
# Win+I → Einstellungen, Win+Tab → Aufgabenansicht.
shortcut="$EASYLINUX_OPT/bin/easylinux-shortcut"
"$shortcut" launch easylinux-taskmanager.desktop Taskmanager Ctrl+Shift+Esc >/dev/null
"$shortcut" clear ksmserver "Log Out" >/dev/null
"$shortcut" launch easylinux-sessionmenu.desktop Sicherheitsoptionen Ctrl+Alt+Del >/dev/null
# Win+I öffnet die Einstellungen (vorher: KDE-Systemeinstellungen)
"$shortcut" clear systemsettings.desktop _launch >/dev/null
"$shortcut" launch easylinux-settings.desktop Einstellungen Meta+I >/dev/null
# Win+Tab = Aufgabenansicht (Übersicht aller Fenster), Alt+Tab bleibt Fensterwechsel
"$shortcut" set kwin "Walk Through Windows" Alt+Tab >/dev/null
"$shortcut" set kwin Overview Meta+W Meta+Tab >/dev/null
ok "Tastenkürzel eingerichtet"
