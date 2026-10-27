#!/usr/bin/python3
"""Root-Helfer der Sicherheit-App (aufgerufen über pkexec).

Kann nur genau diese Aktionen:
  status            → Firewall- und Sicherungspunkt-Zustand als JSON
  firewall-on       → Firewall (ufw) einschalten
  setup-antivirus   → ClamAV installieren, Virensignaturen laden, tägliche Aktualisierung einschalten
Fortschritt kommt als JSON-Zeilen: {"progress": 0–1, "text": "…"} und am Ende {"done": true, "ok": …}.
Von easyLinux installierte Pakete und Dienste werden vermerkt, damit uninstall.sh sie wieder entfernt.
"""
import json
import os
import re
import shutil
import subprocess
import sys

STATE = "/var/lib/easylinux"


def emit(**data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


def remember(name, value):
    os.makedirs(STATE, exist_ok=True)
    path = os.path.join(STATE, name)
    lines = open(path).read().splitlines() if os.path.exists(path) else []
    if value not in lines:
        with open(path, "a") as fh:
            fh.write(value + "\n")


def firewall():
    if shutil.which("ufw"):
        out = subprocess.run(["ufw", "status"], capture_output=True, text=True, env={"LANG": "C", "PATH": "/usr/bin"}).stdout
        return {"installed": True, "tool": "ufw", "active": "Status: active" in out}
    if shutil.which("firewall-cmd"):
        r = subprocess.run(["firewall-cmd", "--state"], capture_output=True, text=True)
        return {"installed": True, "tool": "firewalld", "active": r.stdout.strip() == "running"}
    return {"installed": False, "tool": "", "active": False}


def snapshots():
    if not shutil.which("snapper") or not os.path.exists("/etc/snapper/configs/root"):
        return {"available": False, "count": 0, "last": ""}
    out = subprocess.run(["snapper", "--jsonout", "-c", "root", "list"], capture_output=True, text=True).stdout
    try:
        snaps = [s for s in json.loads(out).get("root", []) if s.get("number", 0) != 0]
    except ValueError:
        snaps = []
    return {"available": True, "count": len(snaps), "last": snaps[-1].get("date", "") if snaps else ""}


def status():
    emit(firewall=firewall(), snapshots=snapshots())


def firewall_on():
    fw = firewall()
    if fw["tool"] == "ufw":
        r = subprocess.run(["ufw", "--force", "enable"], capture_output=True, text=True)
        subprocess.run(["systemctl", "enable", "--now", "ufw.service"], capture_output=True)
    elif fw["tool"] == "firewalld":
        r = subprocess.run(["systemctl", "enable", "--now", "firewalld.service"], capture_output=True, text=True)
    else:
        return emit(done=True, ok=False, error="Keine Firewall installiert")
    emit(done=True, ok=r.returncode == 0, error=r.stderr.strip()[-300:])


def setup_antivirus():
    if subprocess.run(["pacman", "-Qq", "clamav"], capture_output=True).returncode != 0:
        emit(progress=0.05, text="Virenschutz wird installiert …")
        r = subprocess.run(["pacman", "-S", "--needed", "--noconfirm", "clamav"], capture_output=True, text=True)
        if r.returncode != 0:
            return emit(done=True, ok=False, error=(r.stdout + r.stderr).strip()[-400:])
        remember("packages.txt", "clamav")
    emit(progress=0.2, text="Virensignaturen werden geladen (ca. 250 MB) …")
    # freshclam meldet Fortschritt pro Datei; grob auf 20–95 % abbilden
    proc = subprocess.Popen(["freshclam", "--stdout"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    files = 0
    for line in proc.stdout:
        if re.search(r"(daily|main|bytecode)\.(cvd|cld).*(updated|up-to-date|database available)", line, re.I):
            files += 1
            emit(progress=min(0.95, 0.2 + 0.25 * files), text="Virensignaturen werden geladen …")
    proc.wait()
    if not any(os.path.exists(f"/var/lib/clamav/main.{ext}") for ext in ("cvd", "cld")):
        return emit(done=True, ok=False, error="Die Virensignaturen konnten nicht geladen werden. Besteht eine Internetverbindung?")
    # Signaturen täglich aktualisieren (Timer, falls vorhanden – sonst der Dienst im Hintergrund)
    units = subprocess.run(["systemctl", "list-unit-files", "clamav-freshclam-once.timer", "--no-legend"],
                           capture_output=True, text=True).stdout
    unit = "clamav-freshclam-once.timer" if units.strip() else "clamav-freshclam.service"
    subprocess.run(["systemctl", "enable", "--now", unit], capture_output=True)
    remember("units.txt", unit)
    emit(done=True, ok=True, error="")


def main():
    actions = {"status": status, "firewall-on": firewall_on, "setup-antivirus": setup_antivirus}
    if len(sys.argv) != 2 or sys.argv[1] not in actions:
        print("Aufruf: helper.py status|firewall-on|setup-antivirus", file=sys.stderr)
        return 2
    os.environ["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/bin"
    actions[sys.argv[1]]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
