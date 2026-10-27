#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Doppelklick auf Programmdateien (.AppImage, .deb, …) öffnet die easyLinux-Installation.
backup_config mimeapps.list
for t in application/vnd.appimage application/x-iso9660-appimage application/x-appimage application/vnd.flatpak.ref \
         application/x-alpm-package application/vnd.debian.binary-package application/x-deb application/x-rpm; do
    kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "$t" easylinux-open.desktop
done
ok "Programme lassen sich per Doppelklick installieren"
