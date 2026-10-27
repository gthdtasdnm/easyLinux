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

# Datei, die easyLinux im Benutzerverzeichnis neu anlegt (außerhalb von ~/.config) –
# wird beim Deinstallieren gelöscht.
user_put() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")" "$EASYLINUX_STATE"
    grep -qxF "$dest" "$EASYLINUX_STATE/created.txt" 2>/dev/null || echo "$dest" >> "$EASYLINUX_STATE/created.txt"
    cp "$src" "$dest"
}

remove_user_files() {
    [ -f "$EASYLINUX_STATE/created.txt" ] || return 0
    xargs -r -d '\n' rm -f < "$EASYLINUX_STATE/created.txt"
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

# ---------------------------------------------------------------------------
# Systemweite Änderungen (brauchen root). Alles wird in $EASYLINUX_SYS protokolliert,
# damit uninstall.sh es vollständig zurücknehmen kann.
EASYLINUX_SYS=/var/lib/easylinux
EASYLINUX_OPT=/opt/easylinux

root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif [ -n "${SUDO_ASKPASS:-}" ]; then sudo -A "$@"
    else sudo "$@"; fi
}

_sys_log() { root mkdir -p "$EASYLINUX_SYS"; echo "$2" | root tee -a "$EASYLINUX_SYS/$1" >/dev/null; }

# Datei systemweit ablegen. Eine vorhandene Datei wird vorher gesichert.
sys_put() {
    local src="$1" dest="$2" mode="${3:-644}"
    root mkdir -p "$EASYLINUX_SYS/backup"
    if ! root grep -qxF "$dest" "$EASYLINUX_SYS/files.txt" 2>/dev/null; then
        if [ -e "$dest" ]; then
            root mkdir -p "$(dirname "$EASYLINUX_SYS/backup$dest")"
            root cp -a "$dest" "$EASYLINUX_SYS/backup$dest"
        fi
        _sys_log files.txt "$dest"
    fi
    root install -D -m "$mode" "$src" "$dest"
}

# Inhalt von stdin als Systemdatei ablegen.
sys_write() {
    local tmp; tmp="$(mktemp)"; cat > "$tmp"
    sys_put "$tmp" "$1" "${2:-644}"; rm -f "$tmp"
}

# Pakete installieren; gemerkt werden nur die, die vorher fehlten.
pkg_need() {
    local p missing=()
    for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
    [ ${#missing[@]} -eq 0 ] && return 0
    info "Installiere: ${missing[*]}"
    root pacman -S --needed --noconfirm "${missing[@]}"
    root mkdir -p "$EASYLINUX_SYS"
    for p in "${missing[@]}"; do _sys_log packages.txt "$p"; done
}

# systemd-Einheit aktivieren und fürs Deinstallieren merken.
unit_enable() {
    root systemctl daemon-reload
    root systemctl enable --now "$1"
    _sys_log units.txt "$1"
}

user_unit_enable() {
    systemctl --user daemon-reload
    systemctl --user enable --now "$1"
    echo "$1" >> "$EASYLINUX_STATE/user-units.txt"
}

restore_system() {
    [ -d "$EASYLINUX_SYS" ] || return 0
    local f
    if [ -f "$EASYLINUX_SYS/units.txt" ]; then
        while IFS= read -r f; do root systemctl disable --now "$f" 2>/dev/null || true; done < "$EASYLINUX_SYS/units.txt"
    fi
    if [ -f "$EASYLINUX_SYS/files.txt" ]; then
        while IFS= read -r f; do
            if [ -e "$EASYLINUX_SYS/backup$f" ]; then root cp -a "$EASYLINUX_SYS/backup$f" "$f"
            else root rm -f "$f"; fi
        done < "$EASYLINUX_SYS/files.txt"
    fi
    root rm -rf "$EASYLINUX_OPT"
    root systemctl daemon-reload
    if [ -s "$EASYLINUX_SYS/packages.txt" ]; then
        # shellcheck disable=SC2046
        root pacman -Rns --noconfirm $(cat "$EASYLINUX_SYS/packages.txt") || warn "Einige Pakete konnten nicht entfernt werden."
    fi
    root rm -rf "$EASYLINUX_SYS"
    root systemctl try-restart systemd-oomd.service 2>/dev/null || true
}

restore_user_units() {
    [ -f "$EASYLINUX_STATE/user-units.txt" ] || return 0
    local u
    while IFS= read -r u; do systemctl --user disable --now "$u" 2>/dev/null || true; done < "$EASYLINUX_STATE/user-units.txt"
}
