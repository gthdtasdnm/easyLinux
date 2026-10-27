#!/bin/sh
# Veröffentlicht easyLinux auf GitHub:
#   - Paket + pacman-Paketquelle als Release „repo“ (Vorabversion, von dort lädt pacman)
#   - easyLinux-Installer als Release „v<Version>“ (der Download-Link für Einsteiger)
#   tools/release/release.sh [Pfad zum fertigen Installer (apps/installer/build.sh)]
set -e
repo="$(cd "$(dirname "$0")/../.." && pwd)"
ver="$(cat "$repo/VERSION")"
dist="$repo/dist"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
mkdir -p "$dist"
rm -f "$dist"/easylinux-*.pkg.tar.zst "$dist"/easylinux.db* "$dist"/easylinux.files*

# Paket bauen (arch=any – enthält nur Quellen; gebaut wird auf dem Zielrechner)
( cd "$repo/packaging" && BUILDDIR="$build" PKGDEST="$dist" makepkg -f --nodeps >/dev/null )
pkg="$(ls "$dist"/easylinux-"$ver"-*-any.pkg.tar.zst)"

# Paketquelle: GitHub kann keine Verweise (Symlinks) – deshalb echte Kopien
repo-add -q "$dist/easylinux.db.tar.gz" "$pkg"
for f in easylinux.db easylinux.files; do rm -f "$dist/$f"; cp "$dist/$f.tar.gz" "$dist/$f"; done

gh release view repo >/dev/null 2>&1 || gh release create repo --prerelease --title "Paketquelle (für pacman)" \
    --notes "Von hier lädt pacman easyLinux und seine Updates. Zum Installieren bitte den Installer aus dem neuesten Release nehmen."
# Alte Paketversionen entfernen, neue hochladen
for old in $(gh release view repo --json assets --jq '.assets[].name' | grep '\.pkg\.tar\.zst$'); do
    [ "$old" = "$(basename "$pkg")" ] || gh release delete-asset repo "$old" -y
done
gh release upload repo --clobber "$pkg" "$dist/easylinux.db" "$dist/easylinux.db.tar.gz" "$dist/easylinux.files" "$dist/easylinux.files.tar.gz"

if [ -n "${1:-}" ]; then
    if gh release view "v$ver" >/dev/null 2>&1; then
        gh release upload "v$ver" --clobber "$1"
    else
        gh release create "v$ver" "$1" --latest --title "easyLinux $ver" \
            --notes "**Installieren:** easyLinux-Installer herunterladen, doppelklicken, „Ausführen“ und „Jetzt installieren“ wählen."
    fi
fi
echo "Veröffentlicht: easyLinux $ver"
