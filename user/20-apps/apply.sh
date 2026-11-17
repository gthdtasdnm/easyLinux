#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Standard-Apps: Videos und Musik im easyLinux-Medienplayer, Bilder in „Fotos“ (die einheitlichen Namen
# setzt das Systempaket für alle Benutzer). Selbst gewählte Standard-Apps bleiben unangetastet: geändert
# wird nur, was leer ist oder noch auf einer früheren easyLinux-Vorgabe steht.
backup_config mimeapps.list
set_default() {
    local app="$1" t cur; shift
    for t in "$@"; do
        cur="$(kreadconfig6 --file mimeapps.list --group "Default Applications" --key "$t")"
        case "$cur" in
            ""|org.kde.haruna.desktop|org.kde.gwenview.desktop)
                kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "$t" "$app" ;;
        esac
    done
}
set_default easylinux-mediaplayer.desktop video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime \
    video/mpeg video/x-ms-wmv video/ogg audio/mpeg audio/mp4 audio/flac audio/ogg audio/x-wav \
    audio/x-vorbis+ogg audio/opus audio/aac
set_default easylinux-photos.desktop image/jpeg image/png image/gif image/webp image/bmp image/tiff \
    image/avif image/heif image/jxl
ok "Standard-Apps festgelegt"
