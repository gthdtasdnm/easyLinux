"""easyLinux Update-Manager: ein Klick, Fortschrittsbalken, Restzeit – kein Terminal.

  easylinux-updater           Fenster öffnen
  easylinux-updater --install Fenster öffnen und gleich aktualisieren (z. B. aus der Erinnerung)
  easylinux-updater --check   nur prüfen und ggf. sanft erinnern (für den täglichen Timer)
"""
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "helper.py")
REMIND_AFTER_DAYS = 7


# ---------------------------------------------------------------- Prüfen (ohne root)

def check_system():
    """[(name, alt, neu, bytes, sicherheit)]"""
    r = subprocess.run(["checkupdates", "--nocolor"], capture_output=True, text=True)
    pkgs = []
    for line in r.stdout.splitlines():
        m = re.match(r"(\S+) (\S+) -> (\S+)", line)
        if m:
            pkgs.append([m.group(1), m.group(2), m.group(3), 0, False])
    if not pkgs:
        return []
    db = os.path.join(os.environ.get("TMPDIR", "/tmp"), f"checkup-db-{os.getuid()}")
    sizes = subprocess.run(["pacman", "-Sp", "--dbpath", db, "--logfile", "/dev/null",
                            "--print-format", "%n %s", *[p[0] for p in pkgs]],
                           capture_output=True, text=True).stdout
    size_of = dict(line.split() for line in sizes.splitlines() if len(line.split()) == 2)
    secure = set()
    if shutil.which("arch-audit"):
        secure = set(subprocess.run(["arch-audit", "-u", "-f", "%n"], capture_output=True, text=True).stdout.split())
    for p in pkgs:
        p[3] = int(size_of.get(p[0], "0") or 0)
        p[4] = p[0] in secure
    return [tuple(p) for p in pkgs]


def check_flatpak():
    if not shutil.which("flatpak"):
        return []
    r = subprocess.run(["flatpak", "remote-ls", "--updates", "--columns=name,application,version"],
                       capture_output=True, text=True)
    return [tuple(line.split("\t")[:3]) for line in r.stdout.splitlines() if line.strip()]


def last_full_update():
    try:
        with open("/var/log/pacman.log", errors="replace") as fh:
            stamps = [line[1:20] for line in fh if "starting full system upgrade" in line]
        if stamps:
            return datetime.datetime.fromisoformat(stamps[-1].replace("T", " ")[:19])
    except (OSError, ValueError):
        pass
    return None


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024


def remind():
    """Sanfte Erinnerung: nur wenn Updates sich stauen oder Sicherheitsupdates warten."""
    pkgs = check_system()
    if not pkgs:
        return
    security = sum(1 for p in pkgs if p[4])
    last = last_full_update()
    days = (datetime.datetime.now() - last).days if last else 999
    if security == 0 and days < REMIND_AFTER_DAYS:
        return
    title = "Sicherheitsupdates verfügbar" if security else "Updates verfügbar"
    body = f"{len(pkgs)} Updates warten" + (f", davon {security} wichtige Sicherheitsupdates." if security else
                                            f" – das letzte Update ist {days} Tage her.")
    if shutil.which("notify-send"):
        r = subprocess.run(["notify-send", "-a", "Updates", "-i", "system-software-update",
                            "-A", "open=Jetzt aktualisieren", "-A", "later=Später", title, body],
                           capture_output=True, text=True)
        if r.stdout.strip() == "open":
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "--install"], start_new_session=True)


# ---------------------------------------------------------------- Oberfläche

def gui():
    from PySide6.QtCore import QObject, QProcess, QTimer, Property, Signal, Slot
    from PySide6.QtGui import QGuiApplication, QIcon
    from PySide6.QtQml import QQmlApplicationEngine

    class Backend(QObject):
        changed = Signal()

        def __init__(self):
            super().__init__()
            self._state = "checking"     # checking | uptodate | available | updating | done | error
            self._pkgs, self._flatpaks = [], []
            self._progress, self._text, self._eta, self._error = 0.0, "", "", ""
            self._reboot = False
            self._started = 0.0
            self._buffer = ""
            self.proc = None
            self.install_now = "--install" in sys.argv
            self.check()

        def _set(self, **kw):
            for k, v in kw.items():
                setattr(self, "_" + k, v)
            self.changed.emit()

        @Slot()
        def check(self):
            self._set(state="checking")

            def work():
                pkgs, flat = check_system(), check_flatpak()
                QTimer.singleShot(0, self, lambda: self._checked(pkgs, flat))
            threading.Thread(target=work, daemon=True).start()

        def _checked(self, pkgs, flat):
            self._set(pkgs=pkgs, flatpaks=flat, state="available" if pkgs or flat else "uptodate")
            if self.install_now and self._state == "available":
                self.install_now = False
                self.update()

        @Slot()
        def update(self):
            self._set(state="updating", progress=0.0, text="Update wird vorbereitet", eta="", error="", reboot=False)
            self._started = time.monotonic()
            if self._pkgs:
                self.proc = QProcess(self)
                self.proc.readyReadStandardOutput.connect(self._read)
                self.proc.finished.connect(self._helper_finished)
                self.proc.start("pkexec", [HELPER, "system-update"])
            else:
                self._flatpak_update()

        def _read(self):
            self._buffer += bytes(self.proc.readAllStandardOutput()).decode(errors="replace")
            while "\n" in self._buffer:
                line, self._buffer = self._buffer.split("\n", 1)
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if msg.get("done"):
                    self._result = msg
                    continue
                p = msg.get("progress", self._progress) * (0.9 if self._flatpaks else 1.0)
                self._set(progress=p, text=msg.get("text", ""), eta=self._estimate(p))

        def _estimate(self, p):
            elapsed = time.monotonic() - self._started
            if p < 0.08 or elapsed < 15:
                return "Restzeit wird berechnet …"
            rest = elapsed * (1 - p) / p
            if rest < 60:
                return "Noch weniger als eine Minute"
            return f"Noch etwa {round(rest / 60)} Minute{'n' if round(rest / 60) != 1 else ''}"

        def _helper_finished(self, code, _status):
            res = getattr(self, "_result", None)
            if code in (126, 127) and not res:  # Passwortabfrage abgebrochen
                return self._set(state="available")
            if not res or not res.get("ok"):
                err = (res or {}).get("error") or "Das Update wurde unerwartet beendet."
                return self._set(state="error", error=err)
            self._reboot = res.get("reboot", False)
            self._flatpak_update()

        def _flatpak_update(self):
            if not self._flatpaks:
                return self._finish()
            self._set(text="Apps (Flatpak) werden aktualisiert", progress=max(self._progress, 0.9))
            fp = QProcess(self)
            fp.finished.connect(lambda code, _s: self._finish() if code == 0 else
                                self._set(state="error", error="Die Apps (Flatpak) konnten nicht aktualisiert werden."))
            fp.start("flatpak", ["update", "-y", "--noninteractive"])
            self._fp = fp

        def _finish(self):
            self._set(state="done", progress=1.0, eta="", pkgs=[], flatpaks=[])

        @Slot()
        def reboot(self):
            QProcess.startDetached("qdbus6", ["org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndReboot"])

        @Slot()
        def openSnapshots(self):
            QProcess.startDetached("btrfs-assistant-launcher", [])

        @Property(str, notify=changed)
        def state(self): return self._state
        @Property(float, notify=changed)
        def progress(self): return self._progress
        @Property(str, notify=changed)
        def text(self): return self._text
        @Property(str, notify=changed)
        def eta(self): return self._eta
        @Property(str, notify=changed)
        def error(self): return self._error
        @Property(bool, notify=changed)
        def rebootNeeded(self): return self._reboot
        @Property(int, notify=changed)
        def systemCount(self): return len(self._pkgs)
        @Property(int, notify=changed)
        def securityCount(self): return sum(1 for p in self._pkgs if p[4])
        @Property(str, notify=changed)
        def downloadSize(self):
            total = sum(p[3] for p in self._pkgs)
            return human(total) if total else ""
        @Property("QVariantList", notify=changed)
        def systemPackages(self):
            return [{"name": p[0], "old": p[1], "new": p[2], "security": p[4]}
                    for p in sorted(self._pkgs, key=lambda p: (not p[4], p[0]))]
        @Property("QVariantList", notify=changed)
        def flatpakApps(self):
            return [{"name": f[0], "id": f[1], "version": f[2] if len(f) > 2 else ""} for f in self._flatpaks]
        @Property(str, notify=changed)
        def lastUpdate(self):
            last = last_full_update()
            if not last:
                return "Noch kein Update durchgeführt"
            days = (datetime.datetime.now() - last).days
            when = "heute" if days == 0 else "gestern" if days == 1 else f"vor {days} Tagen"
            return f"Letztes Update: {when} ({last:%d.%m.%Y})"
        @Property(bool, constant=True)
        def hasSnapshots(self): return bool(shutil.which("snapper"))

    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Updates")
    app.setDesktopFileName("easylinux-updater")
    app.setWindowIcon(QIcon.fromTheme("system-software-update"))
    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(os.path.join(HERE, "Main.qml"))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    if "--check" in sys.argv:
        remind()
    else:
        sys.exit(gui())
