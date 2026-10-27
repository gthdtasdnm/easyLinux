#!/usr/bin/python3
"""Root-Helfer des Update-Managers (aufgerufen über pkexec).

Führt nur genau eine Aktion aus – das vollständige System-Update – und meldet den
Fortschritt als JSON-Zeilen auf stdout:
  {"phase": "download"|"install"|"finish"|"repair", "progress": 0.0–1.0, "text": "…"}
  {"done": true, "ok": bool, "reboot": bool, "error": "…"}

Löst typische Probleme selbst: hängende pacman-Sperre, veralteter Schlüsselbund,
Spiegelserver mit 404-Fehlern (Spiegel neu bewerten, erneut versuchen).
"""
import json
import os
import re
import shutil
import subprocess
import sys

LOCK = "/var/lib/pacman/db.lck"
LOG = "/var/log/easylinux-update.log"
REBOOT_PKGS = re.compile(r"^(linux[\w-]*|nvidia[\w-]*|systemd|glibc|mesa|amd-ucode|intel-ucode)$")


def emit(**data):
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
    proc = subprocess.Popen(["pacman", *args, "--noconfirm", "--noprogressbar"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            env=dict(os.environ, LANG="C", LC_ALL="C"))
    out, downloaded, upgraded = [], 0, []
    for line in proc.stdout:
        log(line)
        out.append(line)
        s = line.strip()
        if s.endswith("downloading...") and total:
            downloaded += 1
            emit(phase="download", progress=base + span * 0.5 * min(downloaded / total, 1),
                 text=f"Lade herunter ({min(downloaded, total)} von {total})")
        m = re.match(r"\((\s*\d+)/(\s*\d+)\) (upgrading|installing|reinstalling|removing) (\S+)", s)
        if m:
            i, n = int(m.group(1)), int(m.group(2))
            name = m.group(4).rstrip(".")
            upgraded.append(name)
            emit(phase="install", progress=base + span * (0.5 + 0.45 * i / n), text=f"Installiere {name} ({i} von {n})")
        if s.startswith(":: Running post-transaction hooks"):
            emit(phase="finish", progress=base + span * 0.96, text="Schließe die Installation ab")
    proc.wait()
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
    emit(phase="finish", progress=1.0, text="Fertig")
    emit(done=True, ok=True, reboot=reboot, error="")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] != "system-update" or os.geteuid() != 0:
        sys.exit("Aufruf: pkexec helper.py system-update")
    system_update()
