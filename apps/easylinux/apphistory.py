"""App-Verlauf wie bei Windows: wie viel Rechenzeit, Datenträger und Netzwerk jede App seit einem Stichtag
verbraucht hat. Wird jede Minute im Hintergrund fortgeschrieben (der Taskmanager-Dienst läuft immer).

Rechenzeit und Datenträger kommen aus den Zählern der systemd-Gruppe jeder App (cpu.stat, io.stat) und sind
genau. Netzwerk: TCP-Verbindungen über ss – Verbindungen, die zwischen zwei Messungen auf- und wieder
abgebaut werden, fehlen.
"""
import json
import os
import subprocess
import time

from . import netproc, procapps

PATH = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "easylinux", "app-history.json")


class AppHistory:
    def __init__(self, path=PATH):
        self.path = path
        self._last_cg = {}     # cgroup-Pfad → (cpu_usec, io_bytes)
        self._last_net = None  # (Verbindung, pid) → Bytes
        self.data = self._load()

    def _load(self):
        try:
            with open(self.path) as fh:
                data = json.load(fh)
                if isinstance(data.get("apps"), dict):
                    return data
        except (OSError, ValueError):
            pass
        return {"since": time.time(), "apps": {}}

    def save(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(self.data, fh)
        os.replace(tmp, self.path)

    def clear(self):
        self.data = {"since": time.time(), "apps": {}}
        self.save()

    def _entry(self, app):
        key = app.entry.id if app.entry else app.app_id
        e = self.data["apps"].setdefault(key, {"cpu": 0.0, "disk": 0, "net": 0})
        e["name"], e["icon"] = app.name, app.icon
        return e

    def sample(self, monitor):
        """monitor: procapps.Monitor – liefert die laufenden Apps (mit ihren cgroups)."""
        seen = {}
        net_now = self._net_totals()
        net_by_pid = {}
        if self._last_net is not None:
            for key, total in net_now.items():
                prev = self._last_net.get(key, 0)  # neue Verbindung: alles seit ihrem Aufbau zählt
                if total >= prev:
                    net_by_pid[key[1]] = net_by_pid.get(key[1], 0) + total - prev
        self._last_net = net_now
        for app in monitor.update():
            entry = self._entry(app)
            for a in [app] + getattr(app, "extra", []):
                usec, io = procapps._cpu_usec(a.path), procapps._io_bytes(a.path)
                last = self._last_cg.get(a.path)
                if last:
                    entry["cpu"] += max(0, usec - last[0]) / 1e6
                    entry["disk"] += max(0, io - last[1])
                seen[a.path] = (usec, io)
            entry["net"] += sum(net_by_pid.get(p, 0) for p in app.pids)
        self._last_cg = seen
        self.save()

    @staticmethod
    def _net_totals():
        try:
            out = subprocess.run(["ss", "-tinpH"], capture_output=True, text=True, timeout=5).stdout
        except (OSError, subprocess.SubprocessError):
            return {}
        return netproc.parse(out)

    def rows(self):
        return [dict(v, key=k) for k, v in self.data["apps"].items() if v.get("cpu", 0) >= 1 or v.get("net") or v.get("disk")]


def cpu_time_text(seconds):
    """Wie Windows: „0:12:05“ (Stunden:Minuten:Sekunden)."""
    s = int(seconds)
    return f"{s // 3600}:{s % 3600 // 60:02}:{s % 60:02}"


if __name__ == "__main__":
    import tempfile
    assert cpu_time_text(3725) == "1:02:05" and cpu_time_text(5) == "0:00:05"
    with tempfile.TemporaryDirectory() as d:
        h = AppHistory(os.path.join(d, "h.json"))
        m = procapps.Monitor()
        h.sample(m)
        time.sleep(1)
        h.sample(m)
        assert os.path.exists(h.path)
        print("ok", sorted(h.rows(), key=lambda r: -r["cpu"])[:3])
