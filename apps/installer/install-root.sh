#!/bin/bash
# Installiert easyLinux (läuft als root über pkexec, aufgerufen vom Installer).
# Ausgaben „@@STEP …“ zeigt der Installer als Fortschritt an.
REPO_URL="https://github.com/gthdtasdnm/easyLinux/releases/download/repo"

main() {
    set -e
    export LANG=C
    echo "@@STEP Paketquelle von easyLinux wird eingetragen"
    if ! grep -q '^\[easylinux\]' /etc/pacman.conf; then
        printf '\n[easylinux]\nSigLevel = Optional TrustAll\nServer = %s\n' "$REPO_URL" >> /etc/pacman.conf
    fi
    # Hängende Sperre einer abgebrochenen Paketverwaltung lösen
    if [ -e /var/lib/pacman/db.lck ] && ! pgrep -x pacman >/dev/null; then
        rm -f /var/lib/pacman/db.lck
    fi
    echo "@@STEP Wird heruntergeladen und installiert"
    # -Syu statt -Sy: nie nur einen Teil des Systems aktualisieren (das kann Arch/CachyOS beschädigen)
    pacman -Syu --noconfirm --needed easylinux
    echo "@@DONE"
}
main "$@"
exit
