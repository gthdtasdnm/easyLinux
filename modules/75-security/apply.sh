#!/usr/bin/env bash
# Sicherheit: Übersicht wie „Windows-Sicherheit“ (Virenschutz auf Wunsch, Firewall, Updates, Sicherungspunkte, Sperre).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

root chmod 755 "$EASYLINUX_OPT/apps/security/helper.py"
sys_put "$here/org.easylinux.security.policy" /usr/share/polkit-1/actions/org.easylinux.security.policy
sys_put "$here/49-easylinux-security.rules" /etc/polkit-1/rules.d/49-easylinux-security.rules
sys_put "$here/easylinux-security.desktop" /usr/local/share/applications/easylinux-security.desktop
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Sicherheit eingerichtet (Virenschutz lässt sich dort per Klick einschalten)"
