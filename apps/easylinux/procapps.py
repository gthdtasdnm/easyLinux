"""Laufende Apps des Benutzers über ihre systemd-Gruppen (cgroups) finden.

Plasma startet jede App in einer eigenen Gruppe (z. B. app-org.kde.dolphin@….service).
Darüber lassen sich alle Prozesse einer App zusammenfassen, messen und gemeinsam beenden.
"""
import os
import re
import time

from . import desktop

UID = os.getuid()
USER_ROOT = f"/sys/fs/cgroup/user.slice/user-{UID}.slice/user@{UID}.service"
# Gehört zur Oberfläche selbst – nicht als App anzeigen und niemals beenden.
SYSTEM_IDS = {"plasmashell", "kwin_wayland", "ksmserver", "kded6", "org.kde.plasmashell",
              "org.kde.kwin", "xdg-desktop-portal", "easylinux-taskmanager", "easylinux-sessionmenu"}


def _unescape(s):
    return re.sub(r"\\x([0-9a-fA-F]{2})", lambda m: chr(int(m.group(1), 16)), s)


def app_id_from_unit(unit):
    """app-org.kde.dolphin@abc.service / app-flatpak-org.foo-123.scope → Kandidaten für die App-ID."""
    m = re.match(r"app-(.+?)(?:@[^.]*)?\.(service|scope|slice)$", unit)
    if not m:
        return []
    body = _unescape(m.group(1))
    if m.group(2) == "scope":
        body = re.sub(r"-\d+$", "", body)
    cands = [body]
    if "-" in body:  # Präfix des Starters (flatpak-, gnome-, …) weglassen
        cands.append(body.split("-", 1)[1])
    return cands


def _read(path, default=""):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return default


def _cpu_usec(cg):
    for line in _read(os.path.join(cg, "cpu.stat")).splitlines():
        if line.startswith("usage_usec"):
            return int(line.split()[1])
    return 0


class App:
    def __init__(self, unit, path, entry, app_id):
        self.unit, self.path, self.entry, self.app_id = unit, path, entry, app_id
        self.cpu = 0.0      # Prozent einer CPU-Gesamtleistung (alle Kerne = 100 %)
        self.memory = 0     # Bytes
        self.pids = []

    @property
    def name(self):
        if self.entry:
            return self.entry.name
        return self.app_id.split(".")[-1].replace("-", " ").title()

    @property
    def icon(self):
        return self.entry.icon if self.entry else "application-x-executable"

    @property
    def is_app(self):
        """Echte App mit Startmenü-Eintrag (im Gegensatz zu Hintergrunddiensten)."""
        return bool(self.entry) and not self.entry.hidden and not self.unit.endswith("@autostart.service")

    def kill(self):
        """Ganze App mit allen Prozessen beenden (cgroup v2 'cgroup.kill')."""
        try:
            with open(os.path.join(self.path, "cgroup.kill"), "w") as fh:
                fh.write("1")
            return True
        except OSError:
            return False


class Monitor:
    """Liefert bei jedem update() die laufenden Apps mit aktueller CPU-/RAM-Nutzung."""

    def __init__(self):
        self._last = {}       # Pfad → (Zeit, usage_usec)
        self._ncpu = os.cpu_count() or 1

    def _units(self):
        for slice_ in ("app.slice", "background.slice"):
            base = os.path.join(USER_ROOT, slice_)
            try:
                names = os.listdir(base)
            except OSError:
                continue
            for n in names:
                if n.startswith("app-") and not n.startswith("app-dbus") and os.path.isdir(os.path.join(base, n)):
                    yield n, os.path.join(base, n)

    def update(self):
        now = time.monotonic()
        apps = []
        for unit, path in self._units():
            pids = [int(p) for p in _read(os.path.join(path, "cgroup.procs")).split()]
            if not pids:
                # Slices (z. B. D-Bus-Dienste) enthalten Prozesse in Unterordnern
                for sub, _, _ in os.walk(path):
                    pids += [int(p) for p in _read(os.path.join(sub, "cgroup.procs")).split()]
            if not pids:
                continue
            entry, app_id = None, ""
            for cand in app_id_from_unit(unit):
                app_id = app_id or cand
                entry = desktop.find(cand)
                if entry:
                    app_id = cand
                    break
            if app_id in SYSTEM_IDS or (entry and entry.id in SYSTEM_IDS):
                continue
            app = App(unit, path, entry, app_id)
            app.pids = pids
            app.memory = int(_read(os.path.join(path, "memory.current"), "0") or 0)
            usec = _cpu_usec(path)
            last = self._last.get(path)
            if last and now > last[0]:
                app.cpu = max(0.0, (usec - last[1]) / ((now - last[0]) * 1e6 * self._ncpu) * 100)
            self._last[path] = (now, usec)
            apps.append(app)
        # Gleiche App mehrfach gestartet → zusammenfassen
        merged = {}
        for a in apps:
            key = a.entry.id if a.entry else a.app_id
            if key in merged:
                m = merged[key]
                m.cpu += a.cpu
                m.memory += a.memory
                m.pids += a.pids
                m.extra = getattr(m, "extra", []) + [a]
            else:
                merged[key] = a
        return sorted(merged.values(), key=lambda a: (not a.is_app, a.name.lower()))


def kill_app(app):
    ok = app.kill()
    for other in getattr(app, "extra", []):
        ok = other.kill() and ok
    return ok


class SystemStats:
    """Gesamt-Auslastung von Prozessor und Arbeitsspeicher."""

    def __init__(self):
        self._last = None

    def cpu_percent(self):
        vals = [int(x) for x in _read("/proc/stat").splitlines()[0].split()[1:]]
        idle, total = vals[3] + vals[4], sum(vals)
        pct = 0.0
        if self._last:
            d_total, d_idle = total - self._last[0], idle - self._last[1]
            pct = 100.0 * (d_total - d_idle) / d_total if d_total else 0.0
        self._last = (total, idle)
        return pct

    @staticmethod
    def memory():
        info = {}
        for line in _read("/proc/meminfo").splitlines():
            k, v = line.split(":", 1)
            info[k] = int(v.split()[0]) * 1024
        total = info.get("MemTotal", 1)
        used = total - info.get("MemAvailable", 0)
        return used, total


def human_bytes(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024
