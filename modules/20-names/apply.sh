#!/usr/bin/env bash
# Apps heißen so, wie das, was sie tun – und Medien öffnen im Medienplayer.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"

sys_put "$here/easylinux-names.hook" /etc/pacman.d/hooks/easylinux-names.hook
root "$EASYLINUX_OPT/bin/easylinux-names"

# Standard-Programme: Videos und Musik → Medienplayer, Bilder → Bilder
backup_config mimeapps.list
types=()
for t in video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg audio/mpeg audio/mp4 audio/flac audio/ogg audio/x-wav audio/x-vorbis+ogg; do
    types+=("$t=org.kde.haruna.desktop")
done
for t in image/jpeg image/png image/gif image/webp image/bmp image/tiff; do
    types+=("$t=org.kde.gwenview.desktop")
done
for entry in "${types[@]}"; do
    kwriteconfig6 --file mimeapps.list --group "Default Applications" --key "${entry%%=*}" "${entry#*=}"
done
kbuildsycoca6 >/dev/null 2>&1 || true
ok "Einheitliche App-Namen eingerichtet"
