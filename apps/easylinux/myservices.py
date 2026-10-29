"""Eigene Dienste, Server und Skripte finden – für die Seite „Für Entwickler“ der Einstellungen.

Gefunden wird:
  • systemd-Dienste und -Timer, die nicht aus einem Paket stammen
    (~/.config/systemd/user, /etc/systemd/system, /usr/local/lib/systemd/system)
  • „lose“ Programme aus dem Home-Ordner, die nicht als Dienst eingerichtet sind:
    Server mit offenem Port und Skripte (Python, Node …), die im Hintergrund laufen

Lose Programme lassen sich nur beenden – mit „Als Dienst einrichten“ werden sie zu einem
Benutzerdienst und damit wie alle anderen an- und ausschaltbar.
"""
import datetime
import json
import os
import re
import shutil
import signal
import subprocess

HOME = os.path.expanduser("~")
USER_UNITS = os.path.join(HOME, ".config/systemd/user")
SYSTEM_UNITS = ("/etc/systemd/system", "/usr/local/lib/systemd/system")
STATE = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "easylinux", "dienste.json")
# Programme, deren Skripte als „lose“ gelten können
INTERPRETERS = {"python", "python3", "node", "bun", "deno", "ruby", "php", "perl", "java", "npm", "npx", "pnpm",
                "yarn", "uvicorn", "gunicorn", "flask", "streamlit"}
SHOW = ["Id", "Description", "ActiveState", "SubState", "UnitFileState", "FragmentPath", "ExecStart",
        "WorkingDirectory", "ControlGroup", "NextElapseUSecRealtime", "Triggers"]


def _run(args, timeout=10):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=dict(os.environ, LANG="C"))
        return r.returncode, r.stdout, r.stderr
    except (OSError, subprocess.SubprocessError) as exc:
        return 1, "", str(exc)


# ---------- Merkliste: ausgeblendete und schon gesehene Einträge
def load_state():
    try:
        with open(STATE) as f:
            data = json.load(f)
    except (OSError, ValueError):
        data = {}
    data.setdefault("hidden", [])
    data.setdefault("seen", None)  # None = Seite noch nie geöffnet → nichts als „neu“ markieren
    return data


def save_state(data):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".tmp", "w") as f:
        json.dump(data, f, indent=1)
    os.replace(STATE + ".tmp", STATE)


# ---------- systemd-Dateien finden
_owned_cache = {}


def _not_from_package(paths):
    """Nur Dateien, die keinem pacman-Paket gehören (Ergebnis je Datei und Änderungszeit gemerkt)."""
    todo = [p for p in paths if (p, os.path.getmtime(p)) not in _owned_cache]
    if todo:
        _, out, _ = _run(["pacman", "-Qo", *todo])
        owned = {m.group(1) for m in re.finditer(r"^(\S+) is owned by ", out, re.M)}
        for p in todo:
            _owned_cache[(p, os.path.getmtime(p))] = p in owned
    return [p for p in paths if not _owned_cache[(p, os.path.getmtime(p))]]


def _unit_files(folder):
    """Echte Dateien (keine Verknüpfungen wie display-manager.service) mit .service bzw. .timer."""
    try:
        names = os.listdir(folder)
    except OSError:
        return []
    return [os.path.join(folder, n) for n in sorted(names)
            if n.endswith((".service", ".timer")) and "@" not in n
            and os.path.isfile(os.path.join(folder, n)) and not os.path.islink(os.path.join(folder, n))]


def _show(user, units):
    if not units:
        return {}
    _, out, _ = _run(["systemctl", *(["--user"] if user else []), "show", "-p", ",".join(SHOW), "--", *units])
    result = {}
    for block in out.strip().split("\n\n"):
        props = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        if props.get("Id"):
            result[props["Id"]] = props
    return result


def _argv(exec_start):
    m = re.search(r"argv\[\]=(.*?) ;", exec_start or "")
    return m.group(1) if m else ""


def _home_paths(text):
    """Pfade im Home-Ordner, die in einem Befehl vorkommen (auch mit Leerzeichen im Namen)."""
    found = []
    for m in re.finditer(re.escape(HOME) + "/", text):
        words = text[m.start():].split(" ")
        best = None
        for i in range(1, len(words) + 1):
            candidate = " ".join(words[:i])
            if os.path.exists(candidate):
                best = candidate
        if best:
            found.append(best)
    return found


def project_dir(workdir, command):
    """Projektordner: nächster Ordner mit .git über dem Arbeitsordner bzw. Skript – sonst dieser selbst."""
    start = workdir if workdir and workdir.startswith(HOME + "/") else ""
    if not start:
        paths = _home_paths(command)
        # Bevorzugt das Skript selbst, nicht den Interpreter in einer venv (…/comfy-env/bin/python)
        scripts = [p for p in paths if not re.search(r"/(bin|node_modules)/", p)]
        start = (scripts or paths or [""])[-1]
        if os.path.isfile(start):
            start = os.path.dirname(start)
    if not start:
        return ""
    folder = start
    while folder.startswith(HOME + "/"):
        if os.path.exists(os.path.join(folder, ".git")):
            return folder
        folder = os.path.dirname(folder)
    return start


def _when(text):
    """„Wed 2026-10-28 16:07:55 CET“ → „heute 16:07“, „morgen 10:42“ bzw. „30.10. 08:00“."""
    m = re.search(r"(\d{4})-(\d\d)-(\d\d) (\d\d:\d\d)", text or "")
    if not m:
        return ""
    day = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    diff = (day - datetime.date.today()).days
    prefix = "heute" if diff == 0 else "morgen" if diff == 1 else f"{day.day:02d}.{day.month:02d}."
    return f"{prefix} {m.group(4)}"


def _short(path):
    return "~" + path[len(HOME):] if path.startswith(HOME) else path


# ---------- Laufende Programme: Ports und lose Skripte
def _listening():
    """{pid: [Ports]} für TCP-Ports, auf denen eigene Programme lauschen."""
    _, out, _ = _run(["ss", "-tlnpH"])
    ports = {}
    for line in out.splitlines():
        cols = line.split()
        if len(cols) < 6:
            continue
        port = cols[3].rsplit(":", 1)[-1]
        for pid in re.findall(r"pid=(\d+)", cols[5]):
            lst = ports.setdefault(int(pid), [])
            if port.isdigit() and int(port) not in lst:
                lst.append(int(port))
    return ports


def _proc(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
        with open(f"/proc/{pid}/stat") as f:
            stat = f.read().rsplit(")", 1)[1].split()
        ppid, started = int(stat[1]), int(stat[19]) / os.sysconf("SC_CLK_TCK")
        with open(f"/proc/{pid}/cgroup") as f:
            cgroup = f.read().strip().splitlines()[-1].split("::", 1)[-1]
        cwd = os.readlink(f"/proc/{pid}/cwd")
    except (OSError, ValueError, IndexError):
        return None
    return {"pid": pid, "ppid": ppid, "argv": argv, "cgroup": cgroup, "cwd": cwd, "started": started}


def _cgroup_unit(cgroup):
    """Zu welchem Dienst gehört ein Prozess? Letzter Teil des cgroup-Pfads, der auf .service endet."""
    units = [p for p in cgroup.split("/") if p.endswith(".service")]
    return units[-1] if units else ""


def _uptime():
    try:
        return float(open("/proc/uptime").read().split()[0])
    except (OSError, ValueError):
        return 0.0


def _is_loose_candidate(p, ports):
    # Nur, was schon eine Weile läuft – kurze Befehle (auch diese Suche selbst) nicht
    if not p["argv"] or p["pid"] == os.getpid() or _uptime() - p["started"] < 20:
        return False
    exe = os.path.basename(p["argv"][0])
    text = " ".join(p["argv"])
    in_home = any("/." not in path[len(HOME):] for path in _home_paths(text)) or \
        (p["cwd"].startswith(HOME + "/") and "/." not in p["cwd"][len(HOME):])
    if not in_home:
        return False
    if p["pid"] in ports:
        return True
    # Skript eines Interpreters (python foo.py, node server.js …) – keine Hilfsprogramme in versteckten Ordnern
    base = re.sub(r"[\d.]+$", "", exe)
    return base in INTERPRETERS and len(p["argv"]) > 1


def scan():
    """Alle eigenen Dienste und losen Programme als Liste von Einträgen."""
    ports = _listening()
    entries = []
    port_units = {}  # Dienst → Ports seiner Prozesse
    procs = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        try:
            if os.stat(f"/proc/{name}").st_uid != os.getuid():
                continue
        except OSError:
            continue
        p = _proc(int(name))
        if p:
            procs[p["pid"]] = p
    for pid, plist in ports.items():
        p = procs.get(pid) or _proc(pid)
        unit = _cgroup_unit(p["cgroup"]) if p else ""
        if unit:
            port_units.setdefault(unit, set()).update(plist)

    # --- systemd
    for user, folders in ((True, [USER_UNITS]), (False, SYSTEM_UNITS)):
        files = [f for d in folders for f in _unit_files(d)]
        if not user:
            files = _not_from_package(files)
        names = [os.path.basename(f) for f in files]
        props = _show(user, names)
        timers = {n for n in names if n.endswith(".timer")}
        timed = {props.get(t, {}).get("Triggers", "") for t in timers}
        for n in names:
            pr = props.get(n)
            if not pr or n in timed:  # Dienst eines Timers erscheint beim Timer
                continue
            is_timer = n.endswith(".timer")
            service = pr.get("Triggers", "").split()[0] if is_timer and pr.get("Triggers") else n
            spr = (props.get(service) or _show(user, [service]).get(service, {})) if is_timer else pr
            command = _argv(spr.get("ExecStart", ""))
            workdir = spr.get("WorkingDirectory", "")
            project = project_dir(workdir, command)
            next_run = pr.get("NextElapseUSecRealtime", "") if is_timer else ""
            entries.append({
                "id": ("user:" if user else "system:") + n,
                "kind": "timer" if is_timer else "service",
                "unit": n,
                "user": user,
                "name": (spr.get("Description") or pr.get("Description") or n).strip() or n,
                "unitName": n.rsplit(".", 1)[0],
                "running": pr.get("ActiveState") in ("active", "activating", "reloading"),
                "busy": spr.get("ActiveState") == "activating" or (is_timer and spr.get("SubState") == "running"),
                "failed": pr.get("ActiveState") == "failed" or spr.get("ActiveState") == "failed",
                "autostart": pr.get("UnitFileState") in ("enabled", "enabled-runtime", "linked", "alias"),
                "canAutostart": pr.get("UnitFileState") not in ("static", "masked", "generated", "transient"),
                "ports": sorted(port_units.get(service, ())),
                "command": command,
                "project": project,
                "projectShort": _short(project),
                "next": _when(next_run),
                "file": pr.get("FragmentPath", ""),
                "pid": 0,
            })

    # --- lose Programme: nicht in einem Dienst, im Home-Ordner, mit Port oder als Skript
    candidates = {}
    for pid, p in procs.items():
        unit = _cgroup_unit(p["cgroup"])
        managed = bool(unit) and not unit.startswith(("app-", "user@", "dbus-"))
        if not managed and _is_loose_candidate(p, ports):
            candidates[pid] = p
    for pid, p in candidates.items():
        # Kind eines anderen Kandidaten (npm start → node start.js): nur den obersten zeigen
        parent, child_ports = p["ppid"], list(ports.get(pid, []))
        top = True
        while parent > 1:
            if parent in candidates:
                top = False
                break
            parent = procs.get(parent, {}).get("ppid", 0)
        if not top:
            continue
        for other, q in candidates.items():  # Ports der Kindprozesse dazunehmen
            anc = q["ppid"]
            while anc > 1 and anc != pid:
                anc = procs.get(anc, {}).get("ppid", 0)
            if anc == pid:
                child_ports += ports.get(other, [])
        command = " ".join(p["argv"])
        project = project_dir(p["cwd"], command)
        script = next((os.path.basename(a) for a in p["argv"][1:] if not a.startswith("-")), "")
        folder = os.path.basename(project) if project else ""
        entries.append({
            "id": f"loose:{project}:{command}",
            "kind": "loose",
            "unit": "",
            "user": True,
            "name": " – ".join(x for x in (folder, script or os.path.basename(p["argv"][0])) if x),
            "unitName": suggest_name(project, p["argv"]),
            "running": True, "busy": False, "failed": False,
            "autostart": False, "canAutostart": False,
            "ports": sorted(set(child_ports)),
            "command": command,
            "project": project,
            "projectShort": _short(project),
            "next": "",
            "file": "",
            "pid": pid,
            "cwd": p["cwd"],
            "argv": p["argv"],
        })
    return entries


def suggest_name(project, argv):
    base = os.path.basename(project) if project else ""
    script = next((a for a in argv[1:] if not a.startswith("-")), "")
    script = os.path.splitext(os.path.basename(script))[0]
    if script in ("", "main", "index", "server", "app", "start", "run", "dev", "vite"):
        script = ""
    name = base if not script or script == base else f"{base}-{script}"
    name = re.sub(r"[^a-z0-9-]+", "-", name.lower()).strip("-")
    return name or "mein-dienst"


# ---------- Schalten
def _systemctl(user, *args):
    code, _, err = _run(["systemctl", *(["--user"] if user else []), *args], timeout=120)
    return code == 0, err.strip()


def set_running(entry, on):
    if entry["kind"] == "loose":
        return stop_loose(entry["pid"]) if not on else (False, "Lose Programme lassen sich nicht starten.")
    return _systemctl(entry["user"], "start" if on else "stop", entry["unit"])


def set_autostart(entry, on):
    return _systemctl(entry["user"], "enable" if on else "disable", entry["unit"])


def restart(entry):
    return _systemctl(entry["user"], "restart", entry["unit"])


def stop_loose(pid):
    """Programm samt Kindprozessen beenden (erst freundlich, dann hart)."""
    try:
        os.killpg(os.getpgid(pid), signal.SIGTERM) if os.getpgid(pid) != os.getpgid(0) else os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return True, ""
    except OSError as exc:
        return False, str(exc)
    return True, ""


def _quote(arg):
    """Ein Argument für ExecStart= (systemd versteht Anführungszeichen wie die Shell, % muss verdoppelt werden)."""
    arg = arg.replace("%", "%%")
    return arg if re.fullmatch(r"[\w@%+=:,./-]+", arg) else '"' + arg.replace("\\", "\\\\").replace('"', '\\"') + '"'


def make_service(entry, name, description, autostart):
    """Loses Programm in einen Benutzerdienst umwandeln: Datei anlegen, Programm beenden, Dienst starten."""
    name = re.sub(r"[^a-zA-Z0-9_-]+", "-", name).strip("-")
    if not name:
        return False, "Bitte einen Namen eingeben."
    path = os.path.join(USER_UNITS, name + ".service")
    if os.path.exists(path):
        return False, f"Es gibt schon einen Dienst „{name}“."
    argv = list(entry["argv"])
    if not argv[0].startswith("/"):  # Dienste kennen den PATH der Konsole nicht → vollen Pfad eintragen
        # Über den PATH suchen (python3 → /usr/bin/python3), nicht die echte Datei (python3.14 – weg nach Updates)
        found = shutil.which(argv[0], path=os.path.join(entry.get("cwd", HOME), "node_modules/.bin") + ":" +
                             os.environ.get("PATH", "/usr/bin"))
        try:
            argv[0] = found or os.readlink(f"/proc/{entry['pid']}/exe")
        except OSError:
            return False, f"„{argv[0]}“ wurde nicht gefunden."
    text = (
        "# Angelegt von easyLinux (Einstellungen › Für Entwickler)\n"
        "[Unit]\n"
        f"Description={description.strip() or name}\n\n"
        "[Service]\n"
        f"WorkingDirectory={entry.get('cwd') or HOME}\n"
        f"ExecStart={' '.join(_quote(a) for a in argv)}\n"
        f"Environment=PATH={os.environ.get('PATH', '/usr/local/bin:/usr/bin')}\n"
        "Restart=on-failure\n\n"
        "[Install]\n"
        "WantedBy=default.target\n"
    )
    os.makedirs(USER_UNITS, exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    _systemctl(True, "daemon-reload")
    stop_loose(entry["pid"])
    # Kurz warten, bis der Port frei ist – sonst scheitert der Dienst beim ersten Start
    for _ in range(30):
        if not os.path.exists(f"/proc/{entry['pid']}"):
            break
        subprocess.run(["sleep", "0.1"])
    ok, err = _systemctl(True, "enable" if autostart else "start", *(["--now"] if autostart else []), name + ".service")
    return ok, err


# ---------- Anweisung für Coding-Agenten (Claude Code, Codex, Gemini …)
AGENT_FILES = [  # (Ordner des Agenten, Datei darin)
    (".claude", "CLAUDE.md"),
    (".codex", "AGENTS.md"),
    (".gemini", "GEMINI.md"),
]
BEGIN = "<!-- easyLinux: eigene Dienste – Anfang (wird von easyLinux verwaltet) -->"
END = "<!-- easyLinux: eigene Dienste – Ende -->"
AGENT_TEXT = f"""{BEGIN}
## Dienste, Server und Hintergrund-Skripte (easyLinux)

Auf diesem Computer werden eigene Dienste in den easyLinux-Einstellungen (System › Für Entwickler)
gesammelt angezeigt und an-/ausgeschaltet. Damit sie dort auftauchen:

- Alles, was dauerhaft oder im Hintergrund laufen soll (Webserver, Bots, Watcher, Datenbank-Starter …),
  als **systemd-Benutzerdienst** anlegen: `~/.config/systemd/user/<projekt>-<zweck>.service`
  – nicht mit `nohup`, `&`, `screen`/`tmux`, crontab oder als Systemdienst in `/etc/systemd/system`.
- In der Datei: `Description=` mit einer kurzen, verständlichen Beschreibung auf Deutsch,
  `WorkingDirectory=` = Projektordner, `ExecStart=` mit absoluten Pfaden (z. B. Python aus der venv),
  `Restart=on-failure`, `[Install] WantedBy=default.target`.
- Wiederkehrende Aufgaben als `<name>.timer` + `<name>.service` (ohne `[Install]` im Service).
- Danach `systemctl --user daemon-reload` und `systemctl --user enable --now <name>.service`
  (bzw. `.timer`) – oder nur `start`, wenn der Benutzer keinen Autostart möchte.
- Logs: `journalctl --user -u <name> -f`.
- Beim Entfernen eines Projekts auch den Dienst entfernen (`disable --now`, Datei löschen, `daemon-reload`).
{END}"""


def _agent_targets():
    return [os.path.join(HOME, d, f) for d, f in AGENT_FILES if os.path.isdir(os.path.join(HOME, d))]


def agents_installed():
    return [os.path.basename(os.path.dirname(p)).lstrip(".").capitalize() for p in _agent_targets()]


def agent_hint_enabled():
    for path in _agent_targets():
        try:
            if BEGIN in open(path).read():
                return True
        except OSError:
            pass
    return False


def _strip_block(text):
    return re.sub(r"\n*" + re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "\n", text, flags=re.S).strip("\n")


def set_agent_hint(on):
    """Abschnitt in die globalen Anweisungsdateien der installierten Agenten schreiben bzw. entfernen."""
    for path in _agent_targets():
        try:
            text = open(path).read()
        except FileNotFoundError:
            text = ""
        rest = _strip_block(text)
        new = (rest + "\n\n" if rest else "") + AGENT_TEXT + "\n" if on else (rest + "\n" if rest else "")
        if new == text:
            continue
        if not new.strip() and not os.path.exists(path):
            continue
        if not new.strip():
            os.remove(path)  # Datei gab es nur wegen easyLinux
            continue
        with open(path, "w") as f:
            f.write(new)


if __name__ == "__main__":  # Zum Ausprobieren: python3 -m easylinux.myservices
    for e in scan():
        print(f"{e['kind']:8} {'an ' if e['running'] else 'aus'} {'auto' if e['autostart'] else '    '} "
              f"{e['unitName']:24} {str(e['ports']):14} {e['projectShort']:40} {e['name']}")
