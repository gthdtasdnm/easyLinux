"""Systemdienste (systemd) auflisten – für den Dienste-Tab des Taskmanagers."""
import json
import subprocess

STATES = {"running": "Wird ausgeführt", "exited": "Erledigt", "dead": "Beendet", "failed": "Fehler",
          "waiting": "Wartet", "start": "Startet …", "stop": "Wird beendet …", "auto-restart": "Startet neu …"}
STARTUP = {"enabled": "Automatisch", "enabled-runtime": "Automatisch", "static": "Bei Bedarf",
           "indirect": "Bei Bedarf", "disabled": "Deaktiviert", "masked": "Gesperrt",
           "alias": "Bei Bedarf", "generated": "Automatisch", "transient": "Vorübergehend"}


def _json(*args):
    try:
        out = subprocess.run(["systemctl", *args, "-o", "json", "--no-pager"],
                             capture_output=True, text=True, timeout=10).stdout
        return json.loads(out or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def services():
    files = {u["unit_file"]: u["state"] for u in _json("list-unit-files", "--type=service")}
    result = []
    for u in _json("list-units", "--type=service", "--all"):
        name = u["unit"]
        if u.get("load") != "loaded":
            continue
        template = name.split("@", 1)[0] + "@.service" if "@" in name else None
        startup = files.get(name) or (files.get(template) if template else None) or "static"
        result.append({"name": name.removesuffix(".service"), "unit": name,
                       "description": u.get("description", ""),
                       "running": u.get("sub") == "running",
                       "status": STATES.get(u.get("sub", ""), u.get("sub", "")),
                       "failed": u.get("active") == "failed",
                       "startup": STARTUP.get(startup, startup)})
    return sorted(result, key=lambda s: s["name"].lower())


def control(action, unit):
    """start/stop/restart – systemd fragt per Polkit nach dem Administrator-Passwort."""
    if action not in ("start", "stop", "restart"):
        return False, "Unbekannte Aktion"
    r = subprocess.run(["systemctl", action, unit], capture_output=True, text=True)
    return r.returncode == 0, r.stderr.strip()
