#!/usr/bin/env bash
# Für Entwickler: easyLinux aus diesem Ordner als Paket bauen, installieren und einrichten.
# Einsteiger nehmen den grafischen Installer (easyLinux-Installer, siehe README).
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
( cd "$repo/packaging" && BUILDDIR="$out/build" PKGDEST="$out" makepkg -f >/dev/null )
sudo pacman -U --noconfirm "$out"/easylinux-*.pkg.tar.zst
/opt/easylinux/bin/easylinux-user-setup --force
echo "Fertig. Bitte einmal ab- und wieder anmelden."
