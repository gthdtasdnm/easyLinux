#!/usr/bin/python3
"""Root-Helfer des Update-Managers (aufgerufen über pkexec).

Aktionen:
  system-update     vollständiges System-Update (aus dem Fenster)
  auto-update       automatisches Update im Hintergrund (systemd-Timer, alle 10 Minuten aufgerufen) –
                    läuft höchstens einmal am Tag und nur, wenn niemand den Computer benutzt
  auto-enable on|off  automatische Updates ein- oder ausschalten

system-update meldet den Fortschritt als JSON-Zeilen auf stdout:
  {"phase": "download"|"install"|"finish"|"repair", "progress": 0.0–1.0, "text": "…"}
  {"done": true, "ok": bool, "reboot": bool, "error": "…"}

Löst typische Probleme selbst: hängende pacman-Sperre, veralteter Schlüsselbund,
Spiegelserver mit 404-Fehlern (Spiegel neu bewerten, erneut versuchen).
"""
import contextlib
import datetime
import fcntl
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

LOCK = "/var/lib/pacman/db.lck"
LOG = "/var/log/easylinux-update.log"
PACMAN_LOG = "/var/log/pacman.log"
RUNLOCK = "/run/easylinux-update.lock"
STATE = "/var/lib/easylinux"
AUTO_CONF = f"{STATE}/autoupdate.json"       # {"enabled": bool} – fehlt die Datei, ist es eingeschaltet
AUTO_STATE = f"{STATE}/autoupdate-state.json"  # {"last_ok": Zeitstempel, "last_try": Zeitstempel}
AUTO_RESULT = f"{STATE}/autoupdate-result.json"  # nur wenn wirklich etwas installiert wurde oder es scheiterte
INHIBIT = ["systemd-inhibit", "--what=shutdown:sleep", "--mode=block", "--who=Updates",
           "--why=Updates werden installiert – bitte nicht ausschalten"]
REBOOT_PKGS = re.compile(r"^(linux[\w-]*|nvidia[\w-]*|systemd|glibc|mesa|amd-ucode|intel-ucode)$")


_emit_lock = threading.Lock()


def emit(**data):
    with _emit_lock:
        print(json.dumps(data, ensure_ascii=False), flush=True)


def log(line):
    with open(LOG, "a") as fh:
        fh.write(line)


def pacman_running():
    return subprocess.run(["pgrep", "-x", "pacman"], capture_output=True).returncode == 0


def fix_lock():
    if os.path.exists(LOCK) and not pacman_running():
        os.remove(LOCK)
        emit(phase="repair", progress=0.0, text="Alte Sperre der Paketverwaltung entfernt")


def run_pacman(args, total, base, span):
    """pacman ausführen; Fortschritt aus der Ausgabe ableiten. Gibt (rc, Ausgabe, aktualisierte Pakete) zurück."""
    # Ohne Terminal meldet pacman das Installieren nicht auf stdout – dafür steht jedes Paket in seinem Protokoll
    alpm = open(PACMAN_LOG, errors="replace")
    alpm.seek(0, os.SEEK_END)
    upgraded, stop = [], threading.Event()

    def follow():
        while True:
            line = alpm.readline()
            if not line:
                if stop.is_set():
                    break
                time.sleep(0.3)
                continue
            m = re.search(r"\[ALPM\] (upgraded|installed|reinstalled|downgraded) (\S+)", line)
            if m:
                upgraded.append(m.group(2))
                if total:
                    i = min(len(upgraded), total)
                    emit(phase="install", progress=base + span * (0.5 + 0.45 * i / total),
                         text=f"Installiere {m.group(2)} ({i} von {total})")
    reader = threading.Thread(target=follow, daemon=True)
    reader.start()
    # Während pacman Dateien schreibt, darf der Computer nicht ausgehen oder einschlafen
    proc = subprocess.Popen([*INHIBIT, "pacman", *args, "--noconfirm", "--noprogressbar"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            env=dict(os.environ, LANG="C", LC_ALL="C"))
    out, downloaded = [], 0
    for line in proc.stdout:
        log(line)
        out.append(line)
        s = line.strip()
        if s.endswith("downloading...") and total:
            downloaded += 1
            emit(phase="download", progress=base + span * 0.5 * min(downloaded / total, 1),
                 text=f"Lade herunter ({min(downloaded, total)} von {total})")
        if s.startswith(":: Running post-transaction hooks"):
            emit(phase="finish", progress=base + span * 0.96, text="Schließe die Installation ab")
    proc.wait()
    stop.set()
    reader.join()
    alpm.close()
    return proc.returncode, "".join(out), upgraded


def count_updates():
    r = subprocess.run(["pacman", "-Qu"], capture_output=True, text=True)
    return len([line for line in r.stdout.splitlines() if line.strip()])


def mirror_problem(text):
    return "failed retrieving file" in text or "404" in text or "could not be found" in text \
        or "failed to synchronize" in text


def refresh_mirrors():
    emit(phase="repair", progress=0.02, text="Spiegelserver werden neu bewertet (kann eine Minute dauern)")
    if shutil.which("cachyos-rate-mirrors"):
        subprocess.run(["cachyos-rate-mirrors"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif shutil.which("reflector"):
        subprocess.run(["reflector", "--latest", "20", "--sort", "rate", "--save", "/etc/pacman.d/mirrorlist"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def read_json(path, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    os.makedirs(STATE, exist_ok=True)
    with open(path + ".tmp", "w") as fh:
        json.dump(data, fh)
    os.chmod(path + ".tmp", 0o644)
    os.replace(path + ".tmp", path)


def take_runlock(wait):
    """Verhindert, dass Fenster und Automatik gleichzeitig aktualisieren. None = läuft schon."""
    fh = open(RUNLOCK, "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        if not wait:
            return None
        emit(phase="download", progress=0.0, text="Ein automatisches Update läuft gerade – bitte kurz warten")
        fcntl.flock(fh, fcntl.LOCK_EX)
    return fh


def system_update():
    log("\n==== easyLinux-Update ====\n")
    fix_lock()
    emit(phase="download", progress=0.01, text="Paketlisten werden aktualisiert")
    for attempt in range(2):
        rc, out, _ = run_pacman(["-Sy"], 0, 0, 0)
        if rc == 0:
            break
        if attempt == 0 and mirror_problem(out):
            refresh_mirrors()
            continue
        return emit(done=True, ok=False, reboot=False, error="Die Paketlisten konnten nicht geladen werden. "
                    "Ist der Computer mit dem Internet verbunden?")
    # Schlüsselbund zuerst – sonst scheitern Updates an „unbekannten“ Signaturen
    keyrings = [k for k in ("archlinux-keyring", "cachyos-keyring")
                if subprocess.run(["pacman", "-Q", k], capture_output=True).returncode == 0]
    if keyrings:
        emit(phase="download", progress=0.03, text="Sicherheitsschlüssel werden aktualisiert")
        run_pacman(["-S", "--needed", *keyrings], 0, 0, 0)

    total = count_updates()
    if total == 0:
        mark_ok()
        return emit(done=True, ok=True, reboot=False, error="")
    upgraded = []
    for attempt in range(2):
        rc, out, upgraded = run_pacman(["-Su"], total, 0.05, 0.95)
        if rc == 0:
            break
        fix_lock()
        if attempt == 0 and mirror_problem(out):
            refresh_mirrors()
            run_pacman(["-Syy"], 0, 0, 0)
            continue
        tail = "\n".join(out.strip().splitlines()[-8:])
        return emit(done=True, ok=False, reboot=False,
                    error="Das Update ist fehlgeschlagen. Ihr System wurde nicht verändert "
                          "oder kann über die Sicherungspunkte zurückgesetzt werden.\n\n" + tail)
    reboot = any(REBOOT_PKGS.match(p) for p in upgraded)
    mark_ok()
    emit(phase="finish", progress=1.0, text="Fertig")
    emit(done=True, ok=True, reboot=reboot, error="", count=len(upgraded))


def mark_ok():
    state = read_json(AUTO_STATE, {})
    state["last_ok"] = state["last_try"] = time.time()
    write_json(AUTO_STATE, state)


# ---------------------------------------------------------------- Automatisch im Hintergrund

def auto_enabled():
    return read_json(AUTO_CONF, {}).get("enabled", True)


def on_battery():
    """Laptop ohne Netzteil? Rechner ohne Akku zählen immer als „am Strom“."""
    supplies = glob.glob("/sys/class/power_supply/*")
    def val(path, name):
        try:
            with open(f"{path}/{name}") as fh:
                return fh.read().strip()
        except OSError:
            return ""
    has_battery = any(val(p, "type") == "Battery" and val(p, "scope") != "Device" for p in supplies)
    on_mains = any(val(p, "type") in ("Mains", "USB", "USB_C", "USB_PD") and val(p, "online") == "1" for p in supplies)
    return has_battery and not on_mains


def metered():
    """Getaktete Verbindung (Handy-Hotspot, mobile Daten) laut NetworkManager."""
    r = subprocess.run(["busctl", "get-property", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager",
                        "org.freedesktop.NetworkManager", "Metered"], capture_output=True, text=True)
    return r.stdout.split()[-1:] in (["1"], ["3"])  # 1 = ja, 3 = vermutlich ja


def nobody_using():
    """Alle Sitzungen am Gerät gesperrt – oder gar niemand angemeldet."""
    r = subprocess.run(["loginctl", "list-sessions", "--no-legend"], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        sid = line.split()[0]
        props = dict(l.split("=", 1) for l in subprocess.run(
            ["loginctl", "show-session", sid, "-p", "Class", "-p", "Type", "-p", "Remote", "-p", "LockedHint", "-p", "Active"],
            capture_output=True, text=True).stdout.splitlines() if "=" in l)
        if props.get("Class") == "user" and props.get("Type") in ("wayland", "x11") and props.get("Remote") == "no" \
                and props.get("Active") == "yes" and props.get("LockedHint") != "yes":
            return False
    return True


def auto_update():
    if not auto_enabled():
        return
    state = read_json(AUTO_STATE, {})
    now = time.time()
    last_ok, last_try = state.get("last_ok", 0), state.get("last_try", 0)
    # Einmal am Tag reicht; nach einem Fehlschlag frühestens nach zwei Stunden erneut
    if now - last_ok < 20 * 3600 or now - last_try < 2 * 3600:
        return
    if on_battery() or metered():
        return
    # Normalerweise nur, wenn der Bildschirm gesperrt ist. Wer nie sperrt, bekommt die Updates
    # nach drei Tagen trotzdem – leise im Hintergrund, man kann weiterarbeiten.
    overdue = last_ok and now - last_ok > 3 * 86400
    if not nobody_using() and not overdue:
        return
    lock = take_runlock(wait=False)
    if lock is None or pacman_running():
        return
    state["last_try"] = now
    write_json(AUTO_STATE, state)

    # Fortschritt (JSON-Zeilen) mitlesen statt ausgeben
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        system_update()
    result = {}
    for line in buf.getvalue().splitlines():
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("done"):
            result = msg
    flatpak_ok = True
    if result.get("ok") and shutil.which("flatpak"):
        r = subprocess.run([*INHIBIT, "flatpak", "update", "--system", "-y", "--noninteractive"],
                           capture_output=True, text=True)
        log(r.stdout + r.stderr)
        flatpak_ok = r.returncode == 0
    if result.get("count") or not result.get("ok"):
        write_json(AUTO_RESULT, {"time": datetime.datetime.now().isoformat(timespec="seconds"),
                                 "ok": bool(result.get("ok")), "count": result.get("count", 0),
                                 "reboot": bool(result.get("reboot")), "flatpak_ok": flatpak_ok})


if __name__ == "__main__":
    if os.geteuid() != 0:
        sys.exit("Aufruf: pkexec helper.py system-update | auto-update | auto-enable on|off")
    args = sys.argv[1:]
    if args == ["system-update"]:
        _lock = take_runlock(wait=True)
        system_update()
    elif args == ["auto-update"]:
        auto_update()
    elif len(args) == 2 and args[0] == "auto-enable" and args[1] in ("on", "off"):
        write_json(AUTO_CONF, {"enabled": args[1] == "on"})
    else:
        sys.exit("Aufruf: pkexec helper.py system-update | auto-update | auto-enable on|off")
