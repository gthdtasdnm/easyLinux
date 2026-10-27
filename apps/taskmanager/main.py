"""easyLinux Taskmanager – Apps statt Prozesse, ein großer „Task beenden“-Knopf.

Läuft vorgeladen im Hintergrund (--background) und erscheint sofort per Strg+Umschalt+Esc.
Derselbe Prozess zeigt auch den Strg+Alt+Entf-Bildschirm (--session-menu), damit beides
auch unter hoher Last ohne Startverzögerung erscheint.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from PySide6.QtCore import QAbstractListModel, QModelIndex, QObject, QProcess, Qt, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from easylinux import procapps, single

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


class AppModel(QAbstractListModel):
    ROLES = {Qt.UserRole + i: r for i, r in enumerate(
        (b"key", b"name", b"iconName", b"cpu", b"memory", b"memoryText", b"isApp", b"count"))}

    def __init__(self):
        super().__init__()
        self.apps = []

    def roleNames(self):
        return self.ROLES

    def rowCount(self, parent=QModelIndex()):
        return len(self.apps)

    def data(self, index, role):
        a = self.apps[index.row()]
        r = self.ROLES.get(role)
        return {
            b"key": a.entry.id if a.entry else a.app_id,
            b"name": a.name,
            b"iconName": a.icon,
            b"cpu": round(a.cpu, 1),
            b"memory": a.memory,
            b"memoryText": procapps.human_bytes(a.memory),
            b"isApp": a.is_app,
            b"count": len(a.pids),
        }.get(r)

    def set_apps(self, apps):
        old = [self.data(self.index(i), Qt.UserRole) for i in range(len(self.apps))]
        new = [(a.entry.id if a.entry else a.app_id) for a in apps]
        if old == new:
            self.apps = apps
            self.dataChanged.emit(self.index(0), self.index(len(apps) - 1))
        else:
            self.beginResetModel()
            self.apps = apps
            self.endResetModel()


class Backend(QObject):
    statsChanged = Signal()
    message = Signal(str)

    def __init__(self):
        super().__init__()
        self.model = AppModel()
        self.monitor = procapps.Monitor()
        self.system = procapps.SystemStats()
        self._cpu, self._mem_used, self._mem_total = 0.0, 0, 1
        self.timer = QTimer(interval=1500)
        self.timer.timeout.connect(self.refresh)

    @Slot()
    def refresh(self):
        self.model.set_apps(self.monitor.update())
        self._cpu = self.system.cpu_percent()
        self._mem_used, self._mem_total = self.system.memory()
        self.statsChanged.emit()

    @Slot(bool)
    def setActive(self, active):
        """Im Hintergrund nicht messen – spart Strom und Rechenzeit."""
        if active:
            self.refresh()
            self.timer.start()
        else:
            self.timer.stop()

    @Slot(str)
    def endTask(self, key):
        for a in self.model.apps:
            if (a.entry.id if a.entry else a.app_id) == key:
                if procapps.kill_app(a):
                    self.message.emit(f"„{a.name}“ wurde beendet.")
                else:
                    self.message.emit(f"„{a.name}“ konnte nicht beendet werden.")
                QTimer.singleShot(300, self.refresh)
                return

    @Property(QObject, constant=True)
    def apps(self):
        return self.model

    @Property(float, notify=statsChanged)
    def cpu(self):
        return round(self._cpu, 1)

    @Property(float, notify=statsChanged)
    def memoryPercent(self):
        return round(100.0 * self._mem_used / self._mem_total, 1)

    @Property(str, notify=statsChanged)
    def memoryText(self):
        return f"{procapps.human_bytes(self._mem_used)} von {procapps.human_bytes(self._mem_total)}"


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
