#!/bin/bash
# Entfernt easyLinux vollständig (läuft als root über pkexec, aufgerufen vom Installer).
# $1 = Persönlicher Ordner des Benutzers (für die Prüfung auf AppImage-Programme).
# Alles steht in main(), weil pacman diese Datei beim Entfernen selbst löscht.

main() {
    set -u
    export LANG=C
    local home="${1:-/nonexistent}" state=/var/lib/easylinux extra="" removing sysusers kind name
    echo "@@STEP easyLinux wird entfernt"
    # Was der Benutzer über easyLinux installiert hat, soll weiter funktionieren
    if pacman -Qq flatpak >/dev/null 2>&1 && [ -n "$(flatpak list --app --columns=application 2>/dev/null)" ]; then
        pacman -D --asexplicit flatpak >/dev/null
    fi
    if ls "$home"/Programme/*.[Aa]pp[Ii]mage >/dev/null 2>&1 && pacman -Qq fuse2 >/dev/null 2>&1; then
        pacman -D --asexplicit fuse2 >/dev/null
    fi
    # Von der Sicherheit-App nachinstalliert (z. B. Virenschutz)
    [ -f "$state/packages.txt" ] && extra="$(tr '\n' ' ' < "$state/packages.txt")"
    if [ -f "$state/units.txt" ]; then
        while IFS= read -r unit; do systemctl disable --now "$unit" >/dev/null 2>&1 || true; done < "$state/units.txt"
    fi
    case " $extra " in *" clamav "*) find /var/lib/clamav -mindepth 1 -delete 2>/dev/null ;; esac
    # Systembenutzer, die die entfernten Pakete angelegt haben (pacman entfernt sie nicht)
    # shellcheck disable=SC2086
    removing="$(pacman -Rnsp --print-format '%n' easylinux $extra 2>/dev/null)"
    # shellcheck disable=SC2086
    sysusers="$(pacman -Qlq $removing 2>/dev/null | grep '^/usr/lib/sysusers.d/.*\.conf$' \
        | xargs -r awk '$1 ~ /^[ug]!?$/ {print substr($1, 1, 1), $2}' | sort -u)"
    # shellcheck disable=SC2086
    pacman -Rns --noconfirm easylinux $extra || return 1
    while read -r kind name; do
        [ -n "$name" ] || continue
        cat /usr/lib/sysusers.d/*.conf 2>/dev/null | awk -v n="$name" '$2 == n {f=1} END {exit !f}' && continue
        [ "$kind" = u ] && getent passwd "$name" >/dev/null && userdel "$name" 2>/dev/null
        getent group "$name" >/dev/null && groupdel "$name" 2>/dev/null
    done <<< "$sysusers"
    # Paketquelle austragen
    sed -i '/^\[easylinux\]$/,/^Server = .*easyLinux.*$/d' /etc/pacman.conf
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' /etc/pacman.conf  # Leerzeilen am Dateiende
    rm -rf "$state"
    echo "@@DONE"
}
main "$@"
exit
