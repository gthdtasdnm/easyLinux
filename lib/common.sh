# Gemeinsame Funktionen für install.sh, uninstall.sh und die Module.
# Wird per "source" eingebunden, nicht direkt ausgeführt.

EASYLINUX_STATE="${XDG_DATA_HOME:-$HOME/.local/share}/easylinux"
EASYLINUX_BACKUP="$EASYLINUX_STATE/backup"
EASYLINUX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m !\033[0m %s\n' "$*" >&2; }
fail()  { printf '\033[1;31m ✗\033[0m %s\n' "$*" >&2; exit 1; }

require_user_session() {
    [ "$(id -u)" -ne 0 ] || fail "Bitte nicht als root / mit sudo starten, sondern als normaler Benutzer."
    [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ] || warn "Keine KDE-Sitzung erkannt – einige Schritte wirken erst nach dem nächsten Anmelden."
}

# Sichert eine Konfigurationsdatei (Pfad relativ zu ~/.config), bevor easyLinux sie ändert.
# Es wird nur der Zustand VOR der ersten Installation gesichert; spätere Aufrufe überschreiben ihn nicht.
backup_config() {
    local rel="$1" src="$EASYLINUX_CONFIG/$1"
    mkdir -p "$EASYLINUX_BACKUP/config"
    grep -qxF "$rel" "$EASYLINUX_BACKUP/files.txt" 2>/dev/null && return 0
    if [ -e "$src" ]; then
        mkdir -p "$(dirname "$EASYLINUX_BACKUP/config/$rel")"
        cp -a "$src" "$EASYLINUX_BACKUP/config/$rel"
    else
        # Datei gab es vorher nicht → beim Deinstallieren wieder löschen.
        echo "$rel" >> "$EASYLINUX_BACKUP/missing.txt"
    fi
    echo "$rel" >> "$EASYLINUX_BACKUP/files.txt"
}

# Stellt alle gesicherten Dateien wieder her. Plasma muss dabei beendet sein,
# sonst überschreibt es die Dateien beim Beenden mit seinem aktuellen Stand.
restore_configs() {
    local rel
    [ -f "$EASYLINUX_BACKUP/files.txt" ] || return 0
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if grep -qxF "$rel" "$EASYLINUX_BACKUP/missing.txt" 2>/dev/null; then
            rm -f "$EASYLINUX_CONFIG/$rel"
        else
            mkdir -p "$(dirname "$EASYLINUX_CONFIG/$rel")"
            cp -a "$EASYLINUX_BACKUP/config/$rel" "$EASYLINUX_CONFIG/$rel"
        fi
    done < "$EASYLINUX_BACKUP/files.txt"
}

plasma_running() { pgrep -u "$(id -u)" -x plasmashell >/dev/null; }

plasma_stop() {
    plasma_running || return 0
    if systemctl --user -q is-active plasma-plasmashell.service; then
        systemctl --user stop plasma-plasmashell.service
    else
        kquitapp6 plasmashell >/dev/null 2>&1 || true
    fi
    for _ in $(seq 50); do plasma_running || return 0; sleep 0.1; done
    warn "plasmashell hat sich nicht beendet."
}

plasma_start() {
    plasma_running && return 0
    if systemctl --user -q cat plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user start plasma-plasmashell.service
    else
        (kstart plasmashell >/dev/null 2>&1 &)
    fi
}

# Führt ein Plasma-Skript (JavaScript-API der Arbeitsfläche) in der laufenden Sitzung aus.
plasma_eval() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$1")"
}
