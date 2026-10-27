#!/usr/bin/env bash
# Für Entwickler: easyLinux vollständig entfernen (wie „easyLinux entfernen“ im Installer).
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
[ -x /opt/easylinux/bin/easylinux-user-setup ] && /opt/easylinux/bin/easylinux-user-setup --remove
sudo bash "$repo/apps/installer/remove-root.sh" "$HOME"
echo "easyLinux wurde entfernt. Bitte einmal ab- und wieder anmelden."
