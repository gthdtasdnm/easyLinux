#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

# Standard-Apps: Videos und Musik im Medienplayer, Bilder in „Bilder“ (die einheitlichen Namen selbst
# setzt das Systempaket für alle Benutzer).
backup_config mimeapps.list
for t in video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg audio/mpeg audio/mp4 audio/flac audio/ogg audio/x-wav audio/x-vorbis+ogg; do
    kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "$t" org.kde.haruna.desktop
done
for t in image/jpeg image/png image/gif image/webp image/bmp image/tiff; do
    kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "$t" org.kde.gwenview.desktop
done
ok "Standard-Apps festgelegt"
