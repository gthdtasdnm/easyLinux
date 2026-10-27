"""easyLinux Sicherheit – wie „Windows-Sicherheit“: alles Wichtige auf einen Blick, mit Ampelfarben.

Virenschutz (ClamAV, nur auf Wunsch eingerichtet, prüft auf Knopfdruck – kein Dauerscanner),
Firewall, Updates/Sicherheitslücken, Sicherungspunkte und Bildschirmsperre.
"""
import json
import os
import shutil
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from PySide6.QtCore import QObject, QProcess, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from easylinux import desktop, single

NAME = "easylinux-security"
HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "helper.py")
STATE = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "easylinux")
STATE_FILE = os.path.join(STATE, "security.json")
QUARANTINE = os.path.join(STATE, "quarantaene")
SIGNATURES = "/var/lib/clamav"


def load_state():
    try:
        with open(STATE_FILE) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save_state(data):
    os.makedirs(STATE, exist_ok=True)
    with open(STATE_FILE, "w") as fh:
        json.dump(data, fh)


def date_text(ts):
    if not ts:
        return "noch nie"
    days = (time.time() - ts) / 86400
    if days < 1:
        return "heute, " + time.strftime("%H:%M", time.localtime(ts))
    if days < 2:
        return "gestern"
    return time.strftime("%d.%m.%Y", time.localtime(ts))


def german_date(text):
    """„2026-10-27 10:58:03“ → „27.10.2026, 10:58“"""
    try:
        return time.strftime("%d.%m.%Y, %H:%M", time.strptime(text[:16], "%Y-%m-%d %H:%M"))
    except ValueError:
        return text


def signature_time():
    times = [os.path.getmtime(os.path.join(SIGNATURES, f)) for f in ("daily.cld", "daily.cvd")
             if os.path.exists(os.path.join(SIGNATURES, f))]
    return max(times) if times else 0


def check_updates():
    """(Anzahl Updates, Anzahl Sicherheitslücken mit verfügbarer Korrektur)"""
    count = vulns = -1
    try:
        r = subprocess.run(["checkupdates"], capture_output=True, text=True, timeout=120)
        count = len(r.stdout.split("\n")) - 1 if r.stdout.strip() else 0
    except (OSError, subprocess.SubprocessError):
        pass
    if shutil.which("arch-audit"):
        try:
            r = subprocess.run(["arch-audit", "-uq"], capture_output=True, text=True, timeout=60)
            vulns = len([l for l in r.stdout.splitlines() if l.strip()])
        except (OSError, subprocess.SubprocessError):
            pass
    return count, vulns


def autolock():
    r = subprocess.run(["kreadconfig6", "--file", "kscreenlockerrc", "--group", "Daemon", "--key", "Autolock",
                        "--default", "true"], capture_output=True, text=True)
    return r.stdout.strip() != "false"


class Backend(QObject):
    changed = Signal()
    scanChanged = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._state = load_state()
        self._checks = {}
        self._loading = True
        self._busy = ""          # laufende Aktion (Text) – z. B. Einrichten des Virenschutzes
        self._progress = 0.0
        self._scanning = False
        self._scan_count = 0
        self._found = []
        self._scan_target = ""

    # ------------------------------------------------------------ Zustand
    @Slot()
    def refresh(self):
        self._loading = True
        self.changed.emit()

        def work():
            checks = {"lock": autolock()}
            r = subprocess.run(["pkexec", HELPER, "status"], capture_output=True, text=True)
            try:
                checks.update(json.loads(r.stdout.strip().splitlines()[-1]))
            except (ValueError, IndexError):
                checks.update(firewall=None, snapshots=None)
            checks["updates"], checks["vulns"] = check_updates()
            QTimer.singleShot(0, self, lambda: self._loaded(checks))
        threading.Thread(target=work, daemon=True).start()

    def _loaded(self, checks):
        self._checks, self._loading = checks, False
        self.changed.emit()

    @Property(bool, notify=changed)
    def loading(self):
        return self._loading

    @Property("QVariantList", notify=changed)
    def tiles(self):
        """Kacheln: level 0 = in Ordnung (grün), 1 = Hinweis (gelb), 2 = Handlungsbedarf (rot)."""
        c = self._checks
        tiles = []
        # Virenschutz
        sig = signature_time()
        if not shutil.which("clamscan") or not sig:
            tiles.append(dict(key="virus", title="Viren- & Bedrohungsschutz", icon="security-medium", level=1,
                              status="Nicht eingerichtet",
                              text="Prüft heruntergeladene Dateien und Programme vor der Installation auf Schadsoftware. "
                                   "Läuft nicht ständig im Hintergrund und bremst den Computer daher nicht.",
                              action="Einrichten", target="setup-antivirus"))
        else:
            old = time.time() - sig > 7 * 86400
            tiles.append(dict(key="virus", title="Viren- & Bedrohungsschutz", icon="security-high",
                              level=1 if old else 0,
                              status="Virensignaturen veraltet" if old else "Eingerichtet",
                              text=f"Virensignaturen vom {date_text(sig)} · Letzte Prüfung: {date_text(self._state.get('last_scan'))}"
                                   + (f" · {self._state.get('last_result')}" if self._state.get("last_scan") else ""),
                              action="Downloads prüfen", target="scan-downloads"))
        # Firewall
        fw = c.get("firewall")
        if fw is None:
            tiles.append(dict(key="firewall", title="Firewall", icon="security-medium", level=1,
                              status="Unbekannt", text="Der Zustand konnte nicht ermittelt werden.", action="", target=""))
        elif not fw.get("installed"):
            tiles.append(dict(key="firewall", title="Firewall", icon="security-low", level=2, status="Nicht installiert",
                              text="Ohne Firewall kann jeder im selben Netzwerk (z. B. im Café-WLAN) auf offene Dienste zugreifen.",
                              action="", target=""))
        elif not fw.get("active"):
            tiles.append(dict(key="firewall", title="Firewall", icon="security-low", level=2, status="Ausgeschaltet",
                              text="Schützt Ihren Computer vor Zugriffen aus dem Netzwerk, z. B. im öffentlichen WLAN.",
                              action="Einschalten", target="firewall-on"))
        else:
            tiles.append(dict(key="firewall", title="Firewall", icon="security-high", level=0, status="Eingeschaltet",
                              text="Unerwünschte Zugriffe aus dem Netzwerk werden blockiert.", action="", target=""))
        # Updates
        n, v = c.get("updates", -1), c.get("vulns", -1)
        if n < 0:
            tiles.append(dict(key="updates", title="Updates", icon="security-medium", level=1, status="Unbekannt",
                              text="Es konnte nicht geprüft werden, ob Updates vorliegen. Besteht eine Internetverbindung?",
                              action="Update-Manager öffnen", target="app:easylinux-updater"))
        elif v > 0:
            tiles.append(dict(key="updates", title="Updates", icon="security-low", level=2,
                              status=f"{v} Sicherheitslücke{'n' if v != 1 else ''} – Update nötig",
                              text="Für bekannte Sicherheitslücken in installierten Programmen gibt es bereits Korrekturen.",
                              action="Jetzt aktualisieren", target="app:easylinux-updater"))
        elif n > 0:
            tiles.append(dict(key="updates", title="Updates", icon="security-medium", level=1,
                              status=f"{n} Update{'s' if n != 1 else ''} verfügbar",
                              text="Keine bekannten Sicherheitslücken – trotzdem regelmäßig aktualisieren.",
                              action="Update-Manager öffnen", target="app:easylinux-updater"))
        else:
            tiles.append(dict(key="updates", title="Updates", icon="security-high", level=0, status="Auf dem neuesten Stand",
                              text="Alle Programme sind aktuell.", action="", target=""))
        # Sicherungspunkte
        s = c.get("snapshots")
        if s and s.get("available"):
            ok = s.get("count", 0) > 0
            tiles.append(dict(key="snapshots", title="Sicherungspunkte", icon="security-high" if ok else "security-medium",
                              level=0 if ok else 1,
                              status=f"{s['count']} Sicherungspunkte" if ok else "Noch keine Sicherungspunkte",
                              text=("Vor jedem Update wird automatisch ein Sicherungspunkt angelegt. Letzter: "
                                    + german_date(s.get("last", ""))) if ok else
                                   "Vor jedem Update wird automatisch ein Sicherungspunkt angelegt.",
                              action="Verwalten", target="app:btrfs-assistant"))
        elif s is not None:
            tiles.append(dict(key="snapshots", title="Sicherungspunkte", icon="security-medium", level=1,
                              status="Nicht verfügbar",
                              text="Ihr System legt keine automatischen Sicherungspunkte an.", action="", target=""))
        # Bildschirmsperre
        if c.get("lock", True):
            tiles.append(dict(key="lock", title="Bildschirmsperre", icon="security-high", level=0, status="Eingeschaltet",
                              text="Der Bildschirm sperrt sich, wenn Sie den Computer eine Weile nicht benutzen.",
                              action="Einstellungen", target="kcm:kcm_screenlocker"))
        else:
            tiles.append(dict(key="lock", title="Bildschirmsperre", icon="security-medium", level=1, status="Ausgeschaltet",
                              text="Jeder, der an Ihren Computer kommt, kann ihn benutzen, wenn Sie kurz weg sind.",
                              action="Einschalten", target="lock-on"))
        return tiles

    @Property(int, notify=changed)
    def overall(self):
        if self._found:
            return 2  # gefundene Bedrohungen gehen vor
        return max([t["level"] for t in self.tiles] or [0])

    # ------------------------------------------------------------ Aktionen
    @Slot(str)
    def act(self, target):
        if target.startswith("app:"):
            entry = desktop.find(target[4:])
            if entry:
                QProcess.startDetached("kioclient", ["exec", entry.path])
        elif target.startswith("kcm:"):
            QProcess.startDetached("kcmshell6", [target[4:]])
        elif target == "lock-on":
            subprocess.run(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Daemon", "--key", "Autolock", "true"])
            self.message.emit("Die Bildschirmsperre ist eingeschaltet.", True)
            self.refresh()
        elif target == "scan-downloads":
            self.scan(os.path.expanduser("~/Downloads"))
        elif target in ("setup-antivirus", "firewall-on"):
            self._run_helper(target)

    def _run_helper(self, action):
        texts = {"setup-antivirus": ("Virenschutz wird eingerichtet …", "Der Virenschutz ist eingerichtet."),
                 "firewall-on": ("Firewall wird eingeschaltet …", "Die Firewall ist eingeschaltet.")}
        self._busy, self._progress = texts[action][0], 0.0
        self.changed.emit()
        proc = QProcess(self)
        result = {}

        def on_output():
            while proc.canReadLine():
                try:
                    data = json.loads(bytes(proc.readLine()).decode())
                except ValueError:
                    continue
                if "progress" in data:
                    self._progress, self._busy = data["progress"], data.get("text", self._busy)
                    self.changed.emit()
                if data.get("done"):
                    result.update(data)

        def on_finished(code, _status):
            on_output()
            self._busy = ""
            if result.get("ok"):
                self.message.emit(texts[action][1], True)
            elif code in (126, 127):
                self.message.emit("Abgebrochen.", False)
            else:
                self.message.emit("Das hat leider nicht geklappt. " + result.get("error", ""), False)
            self.refresh()

        proc.readyReadStandardOutput.connect(on_output)
        proc.finished.connect(on_finished)
        proc.start("pkexec", [HELPER, action])
        self._proc = proc

    @Property(str, notify=changed)
    def busy(self):
        return self._busy

    @Property(float, notify=changed)
    def progress(self):
        return self._progress

    # ------------------------------------------------------------ Virenprüfung
    @Slot()
    def chooseAndScan(self):
        r = subprocess.run(["kdialog", "--title", "Ordner prüfen", "--getexistingdirectory", os.path.expanduser("~")],
                           capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            self.scan(r.stdout.strip())

    @Slot()
    def scanHome(self):
        self.scan(os.path.expanduser("~"))

    @Slot(str)
    def scan(self, path):
        if self._scanning or not shutil.which("clamscan"):
            return
        self._scanning, self._scan_count, self._found, self._scan_target = True, 0, [], path
        self.scanChanged.emit()
        proc = QProcess(self)
        buf = {"rest": ""}

        def on_output():
            text = buf["rest"] + bytes(proc.readAllStandardOutput()).decode(errors="replace")
            lines = text.split("\n")
            buf["rest"] = lines.pop()
            for line in lines:
                if line.endswith(" FOUND"):
                    file, _, sig = line[:-6].rpartition(": ")
                    self._found.append({"path": file, "name": os.path.basename(file), "threat": sig})
                if line.endswith((" OK", " FOUND", " Empty file")):
                    self._scan_count += 1
            self.scanChanged.emit()

        def on_finished(code, _status):
            on_output()
            self._scanning = False
            n = len(self._found)
            result = "keine Bedrohungen" if n == 0 else f"{n} Bedrohung{'en' if n != 1 else ''} gefunden"
            self._state.update(last_scan=time.time(), last_result=result)
            save_state(self._state)
            if code == 2 and n == 0:
                self.message.emit("Einige Dateien konnten nicht geprüft werden.", False)
            self.scanChanged.emit()
            self.changed.emit()

        proc.readyReadStandardOutput.connect(on_output)
        proc.finished.connect(on_finished)
        # --exclude: eigene Quarantäne nicht erneut melden
        proc.start("clamscan", ["-r", "--stdout", "--no-summary", "--exclude-dir=" + QUARANTINE, path])
        self._scan = proc

    @Slot()
    def cancelScan(self):
        if self._scanning:
            self._scan.kill()

    @Property(bool, notify=scanChanged)
    def scanning(self):
        return self._scanning

    @Property(int, notify=scanChanged)
    def scanCount(self):
        return self._scan_count

    @Property(str, notify=scanChanged)
    def scanTarget(self):
        return self._scan_target.replace(os.path.expanduser("~"), "Persönlicher Ordner", 1)

    @Property("QVariantList", notify=scanChanged)
    def found(self):
        # Inzwischen anderweitig gelöschte Dateien nicht mehr anzeigen
        self._found = [f for f in self._found if os.path.lexists(f["path"])]
        return self._found

    @Slot(str, str)
    def handleThreat(self, path, how):
        """how = quarantine | delete | keep"""
        try:
            if how == "delete":
                os.remove(path)
            elif how == "quarantine":
                os.makedirs(QUARANTINE, exist_ok=True)
                dest = os.path.join(QUARANTINE, f"{int(time.time())}-{os.path.basename(path)}")
                shutil.move(path, dest)
                os.chmod(dest, 0o400)  # nicht mehr ausführbar
        except OSError as exc:
            self.message.emit(f"Das hat nicht geklappt: {exc.strerror}", False)
            return
        self._found = [f for f in self._found if f["path"] != path]
        self.scanChanged.emit()
        self.changed.emit()
        done = {"delete": "gelöscht", "quarantine": "in Quarantäne verschoben (unschädlich gemacht)", "keep": "zugelassen"}
        self.message.emit(f"„{os.path.basename(path)}“ wurde {done[how]}.", True)


def main():
    if single.notify_running(NAME):
        return 0
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Sicherheit")
    app.setDesktopFileName(NAME)
    app.setWindowIcon(QIcon.fromTheme("security-high"))
    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(os.path.join(HERE, "Main.qml"))
    if not engine.rootObjects():
        return 1
    window = engine.rootObjects()[0]

    def on_message(_msg):
        window.showNormal()
        window.raise_()
        window.requestActivate()

    server = single.listen(NAME, on_message)  # noqa: F841 – muss am Leben bleiben
    backend.refresh()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
