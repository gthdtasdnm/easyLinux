"""easyLinux Taskmanager – wie bei Windows: Prozesse, Leistung, Autostart-Apps, Details, Dienste.

Läuft vorgeladen im Hintergrund (--background) und erscheint sofort per Strg+Umschalt+Esc.
Derselbe Prozess zeigt auch den Strg+Alt+Entf-Bildschirm (--session-menu), damit beides
auch unter hoher Last ohne Startverzögerung erscheint.
"""
import os
import signal
import sys
import threading

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from PySide6.QtCore import QAbstractListModel, QModelIndex, QObject, QProcess, Qt, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from easylinux import autostart, procapps, services, single, sysperf

NAME = "easylinux-taskmanager"
HERE = os.path.dirname(os.path.abspath(__file__))
ACK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "easylinux-sessionmenu.ack")

SESSION_ACTIONS = {
    "lock": ["loginctl", "lock-session"],
    # Wie Plasma selbst: erst sperren, dann zum Anmeldebildschirm wechseln
    "switch": ["sh", "-c", "loginctl lock-session && sleep 1 && qdbus6 --system org.freedesktop.DisplayManager "
               "/org/freedesktop/DisplayManager/Seat0 org.freedesktop.DisplayManager.Seat.SwitchToGreeter"],
    "logout": ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"],
    "reboot": ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndReboot"],
    "shutdown": ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndShutdown"],
}


class DictModel(QAbstractListModel):
    """Listenmodell aus Dictionaries; bleibt die Reihenfolge gleich, werden nur Werte aktualisiert
    (so geht die Auswahl beim Aktualisieren nicht verloren)."""

    def __init__(self, roles, key):
        super().__init__()
        self.key = key
        self.rows = []
        self.ROLES = {Qt.UserRole + i: r.encode() for i, r in enumerate(roles)}
        self._names = list(roles)

    def roleNames(self):
        return self.ROLES

    def rowCount(self, parent=QModelIndex()):
        return len(self.rows)

    def data(self, index, role):
        name = self.ROLES.get(role)
        return self.rows[index.row()].get(name.decode()) if name else None

    def set_rows(self, rows):
        if [r[self.key] for r in rows] == [r[self.key] for r in self.rows]:
            self.rows = rows
            if rows:
                self.dataChanged.emit(self.index(0), self.index(len(rows) - 1))
        else:
            self.beginResetModel()
            self.rows = rows
            self.endResetModel()


def pct(v):
    return f"{v:.1f} %".replace(".", ",")


class Backend(QObject):
    statsChanged = Signal()
    perfChanged = Signal()
    autostartChanged = Signal()
    sortChanged = Signal()
    message = Signal(str)

    def __init__(self):
        super().__init__()
        self.apps_model = DictModel(["key", "name", "iconName", "cpu", "cpuText", "memory", "memoryText",
                                     "disk", "diskText", "isApp", "count", "efficient"], "key")
        self.proc_model = DictModel(["pid", "name", "status", "user", "cpu", "cpuText", "memory",
                                     "memoryText", "command", "nice", "own"], "pid")
        self.service_model = DictModel(["unit", "name", "description", "status", "running", "failed",
                                        "startup"], "unit")
        self.monitor = procapps.Monitor()
        self.table = procapps.ProcessTable()
        self.perf = sysperf.Performance()
        self._apps, self._procs, self._services = [], [], []
        self._devices, self._autostart = [], []
        self._cpu, self._mem_used, self._mem_total, self._disk = 0.0, 0, 1, 0.0
        self._page = "processes"
        self._filter = ""
        self._pid_filter = []
        self._sort = {"processes": ("name", False), "details": ("name", False), "services": ("name", False)}
        self.timer = QTimer(interval=1500)
        self.timer.timeout.connect(self.refresh)

    # ------------------------------------------------------------ Steuerung
    @Slot()
    def refresh(self):
        self._devices = self.perf.update()
        cpu = next(d for d in self._devices if d["kind"] == "cpu")
        self._cpu = cpu["value"]
        self._mem_used, self._mem_total = procapps.SystemStats.memory()
        if self._page == "processes":
            self._apps = self.monitor.update()
            self._disk = sum(a.disk for a in self._apps)
            self._show_apps()
        elif self._page == "details":
            self._procs = self.table.update()
            self._show_procs()
        self.statsChanged.emit()
        self.perfChanged.emit()

    @Slot(bool)
    def setActive(self, active):
        """Im Hintergrund nicht messen – spart Strom und Rechenzeit."""
        if active:
            self.refresh()
            self.timer.start()
        else:
            self.timer.stop()

    @Slot(str)
    def setPage(self, page):
        self._page = page
        self._pid_filter = [] if page != "details" else self._pid_filter
        if page == "autostart":
            self.loadAutostart()
        elif page == "services":
            self.loadServices()
        if self.timer.isActive():
            self.refresh()

    @Slot(str)
    def setFilter(self, text):
        self._filter = text.strip().lower()
        self._show_apps()
        self._show_procs()
        self._show_services()

    @Slot(str)
    def sortBy(self, column):
        col, desc = self._sort.get(self._page, ("name", False))
        # Erster Klick: Zahlen absteigend (Größtes oben), Text aufsteigend; erneuter Klick dreht um
        self._sort[self._page] = (column, not desc) if col == column else (column, column not in ("name", "user", "status", "description", "startup"))
        self.sortChanged.emit()
        self._show_apps()
        self._show_procs()
        self._show_services()

    @Property(str, notify=sortChanged)
    def sortColumn(self):
        return self._sort.get(self._page, ("name", False))[0]

    @Property(bool, notify=sortChanged)
    def sortDescending(self):
        return self._sort.get(self._page, ("name", False))[1]

    def _sorted(self, page, rows):
        col, desc = self._sort[page]
        key = (lambda r: str(r[col]).lower()) if isinstance(rows[0][col] if rows else "", str) else (lambda r: r[col])
        return sorted(rows, key=key, reverse=desc)

    # ------------------------------------------------------------ Prozesse (Apps)
    def _show_apps(self):
        rows = []
        for a in self._apps:
            if self._filter and self._filter not in a.name.lower():
                continue
            rows.append({"key": a.entry.id if a.entry else a.app_id, "name": a.name, "iconName": a.icon,
                         "cpu": a.cpu, "cpuText": pct(a.cpu), "memory": a.memory,
                         "memoryText": procapps.human_bytes(a.memory), "disk": a.disk,
                         "diskText": sysperf.human_rate(a.disk), "isApp": a.is_app,
                         "count": len(a.pids), "efficient": a.efficient})
        if rows:
            # Gruppen (Apps / Hintergrundprozesse) bleiben erhalten, sortiert wird innerhalb
            ordered = self._sorted("processes", rows)
            rows = [r for r in ordered if r["isApp"]] + [r for r in ordered if not r["isApp"]]
        self.apps_model.set_rows(rows)

    def _app(self, key):
        return next((a for a in self._apps if (a.entry.id if a.entry else a.app_id) == key), None)

    @Slot(str)
    def endTask(self, key):
        a = self._app(key)
        if not a:
            return
        if procapps.kill_app(a):
            self.message.emit(f"„{a.name}“ wurde beendet.")
        else:
            self.message.emit(f"„{a.name}“ konnte nicht beendet werden.")
        QTimer.singleShot(300, self.refresh)

    @Slot(str, bool)
    def setEfficient(self, key, on):
        a = self._app(key)
        if a and procapps.set_efficient(a, on):
            self.message.emit(f"Effizienzmodus für „{a.name}“ {'eingeschaltet – die App bremst den Computer weniger aus' if on else 'ausgeschaltet'}.")
        QTimer.singleShot(200, self.refresh)

    @Slot(str)
    def openLocation(self, key):
        a = self._app(key)
        exe = a.exe if a else ""
        if exe:
            QProcess.startDetached("dolphin", ["--select", exe])
        else:
            self.message.emit("Der Speicherort konnte nicht ermittelt werden.")

    @Slot(str)
    def showDetailsFor(self, key):
        a = self._app(key)
        self._pid_filter = list(a.pids) if a else []

    @Property(QObject, constant=True)
    def apps(self):
        return self.apps_model

    @Property(str, notify=statsChanged)
    def cpuTotal(self):
        return f"{self._cpu:.0f} %"

    @Property(str, notify=statsChanged)
    def memoryTotal(self):
        return f"{100.0 * self._mem_used / self._mem_total:.0f} %"

    @Property(str, notify=statsChanged)
    def diskTotal(self):
        return sysperf.human_rate(self._disk)

    # ------------------------------------------------------------ Leistung
    @Property("QVariantList", notify=perfChanged)
    def devices(self):
        return self._devices

    # ------------------------------------------------------------ Autostart
    @Slot()
    def loadAutostart(self):
        self._autostart = autostart.entries()
        self.autostartChanged.emit()

    @Property("QVariantList", notify=autostartChanged)
    def autostartApps(self):
        return self._autostart

    @Slot(str, bool)
    def setAutostart(self, did, on):
        try:
            autostart.set_enabled(did, on)
        except OSError as exc:
            self.message.emit(f"Konnte nicht geändert werden: {exc}")
        self.loadAutostart()

    # ------------------------------------------------------------ Details (alle Prozesse)
    def _show_procs(self):
        uid = os.getuid()
        rows = []
        for p in self._procs:
            if self._pid_filter and p["pid"] not in self._pid_filter:
                continue
            if self._filter and self._filter not in p["name"].lower() and self._filter != str(p["pid"]) \
                    and self._filter not in p["user"].lower():
                continue
            rows.append(dict(p, cpuText=pct(p["cpu"]), memoryText=procapps.human_bytes(p["memory"]),
                             own=p["uid"] == uid))
        self.proc_model.set_rows(self._sorted("details", rows) if rows else [])

    @Property(QObject, constant=True)
    def processes(self):
        return self.proc_model

    @Property(bool, notify=statsChanged)
    def detailsFiltered(self):
        return bool(self._pid_filter)

    @Slot()
    def clearPidFilter(self):
        self._pid_filter = []
        self._show_procs()
        self.statsChanged.emit()

    def _proc(self, pid):
        return next((p for p in self._procs if p["pid"] == pid), None)

    @Slot(int, bool)
    def endProcess(self, pid, force):
        p = self._proc(pid)
        sig = signal.SIGKILL if force else signal.SIGTERM
        name = p["name"] if p else str(pid)
        try:
            os.kill(pid, sig)
            self.message.emit(f"„{name}“ ({pid}) wurde beendet.")
        except PermissionError:
            # Prozess eines anderen Benutzers bzw. des Systems → mit Administrator-Passwort
            self._run_admin(["kill", "-KILL" if force else "-TERM", str(pid)], f"„{name}“ ({pid}) wurde beendet.")
        except ProcessLookupError:
            pass
        QTimer.singleShot(300, self.refresh)

    @Slot(int, int)
    def setPriority(self, pid, nice):
        p = self._proc(pid)
        name = p["name"] if p else str(pid)
        try:
            os.setpriority(os.PRIO_PROCESS, pid, nice)
            self.message.emit(f"Priorität von „{name}“ geändert.")
        except PermissionError:
            self._run_admin(["renice", "-n", str(nice), "-p", str(pid)], f"Priorität von „{name}“ geändert.")
        except ProcessLookupError:
            pass
        QTimer.singleShot(300, self.refresh)

    @Slot(int)
    def openProcessLocation(self, pid):
        try:
            QProcess.startDetached("dolphin", ["--select", os.readlink(f"/proc/{pid}/exe")])
        except OSError:
            self.message.emit("Der Speicherort konnte nicht ermittelt werden.")

    def _run_admin(self, cmd, ok_text):
        proc = QProcess(self)
        proc.finished.connect(lambda code, _s: self.message.emit(
            ok_text if code == 0 else "Abgebrochen." if code in (126, 127) else "Das hat nicht geklappt."))
        proc.start("pkexec", cmd)
        self._admin = proc

    # ------------------------------------------------------------ Dienste
    @Slot()
    def loadServices(self):
        def work():
            rows = services.services()
            QTimer.singleShot(0, self, lambda: self._services_loaded(rows))
        threading.Thread(target=work, daemon=True).start()

    def _services_loaded(self, rows):
        self._services = rows
        self._show_services()

    def _show_services(self):
        rows = [s for s in self._services if not self._filter or self._filter in s["name"].lower()
                or self._filter in s["description"].lower()]
        self.service_model.set_rows(self._sorted("services", rows) if rows else [])

    @Property(QObject, constant=True)
    def services(self):
        return self.service_model

    @Slot(str, str)
    def controlService(self, action, unit):
        proc = QProcess(self)
        texts = {"start": "gestartet", "stop": "beendet", "restart": "neu gestartet"}

        def done(code, _s):
            err = bytes(proc.readAllStandardError()).decode(errors="replace")
            if code == 0:
                self.message.emit(f"Dienst „{unit.removesuffix('.service')}“ wurde {texts[action]}.")
            elif "authoriz" in err.lower() or "berechtig" in err.lower():
                self.message.emit("Abgebrochen.")
            else:
                self.message.emit(f"Dienst „{unit.removesuffix('.service')}“: {err.strip()[:200] or 'Fehler'}")
            self.loadServices()
        proc.finished.connect(done)
        proc.start("systemctl", [action, unit])
        self._svc = proc

    # ------------------------------------------------------------ Sonstiges
    @Slot(str)
    def runTask(self, command):
        command = command.strip()
        if command and not QProcess.startDetached("sh", ["-c", command]):
            self.message.emit(f"„{command}“ konnte nicht gestartet werden.")

    @Slot(str)
    def openKcm(self, name):
        QProcess.startDetached("kcmshell6", [name])


def main():
    background = "--background" in sys.argv
    request = b"session" if "--session-menu" in sys.argv else b"show"
    if single.notify_running(NAME, request):
        return 0
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Taskmanager")
    app.setDesktopFileName(NAME)
    app.setWindowIcon(QIcon.fromTheme("utilities-system-monitor"))
    app.setQuitOnLastWindowClosed(False)

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(os.path.join(HERE, "Main.qml"))
    engine.load(os.path.join(HERE, "SessionMenu.qml"))
    if len(engine.rootObjects()) < 2:
        return 1
    window, menu = engine.rootObjects()

    def show():
        window.setProperty("visible", True)
        window.showNormal()
        window.raise_()
        window.requestActivate()

    def on_action(action):
        if action == "taskmanager":
            show()
        elif action in SESSION_ACTIONS:
            QProcess.startDetached(SESSION_ACTIONS[action][0], SESSION_ACTIONS[action][1:])

    def on_message(msg):
        if msg == "session":
            # Quittung für den Notfall-Dienst: die Oberfläche reagiert noch.
            with open(ACK, "w") as fh:
                fh.write(str(os.getpid()))
            menu.open()
        else:
            show()

    def on_menu_visible(visible):
        # Menü zu → vermerken; ein erneutes Strg+Alt+Entf gilt dann nicht als „zweimal gedrückt“
        if not visible:
            with open(ACK, "w") as fh:
                fh.write("closed")

    menu.actionChosen.connect(on_action)
    menu.visibleChanged.connect(on_menu_visible)
    server = single.listen(NAME, on_message)  # noqa: F841 – muss am Leben bleiben
    if not background:
        on_message(request.decode())
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
