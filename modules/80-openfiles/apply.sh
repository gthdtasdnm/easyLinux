#!/usr/bin/env bash
# Programme per Doppelklick installieren (.AppImage, .flatpakref, .pkg.tar.zst; .deb/.rpm → Alternative anbieten).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

pkg_need flatpak fuse2
root flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
# Katalog laden, damit für .deb/.rpm-Dateien passende Flathub-Apps gefunden werden
root flatpak update --appstream -y >/dev/null 2>&1 || true
sys_put "$here/easylinux-mime.xml" /usr/local/share/mime/packages/easylinux.xml
root update-mime-database /usr/local/share/mime >/dev/null 2>&1
sys_put "$here/easylinux-open.desktop" /usr/local/share/applications/easylinux-open.desktop

backup_config mimeapps.list
for t in application/vnd.appimage application/x-iso9660-appimage application/x-appimage application/vnd.flatpak.ref \
         application/x-alpm-package application/vnd.debian.binary-package application/x-deb application/x-rpm; do
    kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "$t" easylinux-open.desktop
done
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Programme lassen sich per Doppelklick installieren"
