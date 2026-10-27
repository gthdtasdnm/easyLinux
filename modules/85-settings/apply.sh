#!/usr/bin/env bash
# Einstellungen mit Windows-Struktur, deutscher Suche und „Installierte Apps“.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

sys_put "$here/easylinux-settings.desktop" /usr/local/share/applications/easylinux-settings.desktop
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Einstellungen eingerichtet"
