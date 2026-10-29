"""easyLinux Einstellungen – wie bei Windows 11 in einem Fenster: links die Bereiche, rechts die Seite.

Die KDE-Einstellungsseiten (KCMs) werden über die kleine C++-Brücke kcmhost/libkcmhost.so direkt im
Fenster angezeigt. Fehlt die Brücke oder ist eine Seite noch eine alte QWidget-KCM, öffnet sie sich
wie bisher in einem eigenen Fenster.
"""
import ctypes
import glob
import os
import pwd
import re
import socket
import subprocess
import sys
import threading

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from functools import lru_cache

from PySide6.QtCore import QObject, QProcess, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from easylinux import desktop, single
from developer import Developer
from display import Display
from snapassist import SnapAssist
from settings_entries import CATEGORIES, ENTRIES

HERE = os.path.dirname(os.path.abspath(__file__))
KCMHOST = os.path.join(HERE, "kcmhost", "libkcmhost.so")
KCM_PLUGINS = "/usr/lib/qt6/plugins/plasma/kcms"
KCM_EMBED_DIRS = ("systemsettings", ".", "kinfocenter")  # QML-Seiten wie in kcmhost.cpp – lassen sich einbetten
KCMHOST_OK = os.path.exists(KCMHOST)
# Ohne diese Pakete funktioniert die Oberfläche nicht – nie zum Deinstallieren anbieten
PROTECTED = {"plasma-desktop", "plasma-workspace", "systemsettings", "kwin", "plasma-login-manager",
             "plasmalogin", "dolphin", "konsole", "kdialog", "pyside6", "cachyos-hello", "cachyos-settings"}


def norm(text):
    text = text.lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        text = text.replace(a, b)
    return text


@lru_cache(maxsize=None)
def available(target):
    """Gibt es die Seite bzw. App auf diesem Computer? (Sonst wird der Eintrag ausgeblendet.)"""
    if target.startswith("kcm_"):
        return bool(glob.glob(f"{KCM_PLUGINS}/**/{target}.so", recursive=True)) or \
            os.path.exists(f"/usr/share/applications/{target}.desktop")
    if target.startswith("app:"):
        return desktop.find(target[4:]) is not None
    return True


@lru_cache(maxsize=None)
def opens_window(target):
    """Öffnet der Eintrag ein eigenes Fenster? (Programme, Aktionen und alte QWidget-Seiten) – für das Pfeil-Symbol."""
    if target.startswith("kcm_"):
        return not (KCMHOST_OK and any(os.path.exists(f"{KCM_PLUGINS}/{d}/{target}.so") for d in KCM_EMBED_DIRS))
    return target.startswith(("app:", "action:"))


def user_info():
    pw = pwd.getpwuid(os.getuid())
    name = pw.pw_gecos.split(",")[0] or pw.pw_name
    avatar = ""
    for path in (f"/var/lib/AccountsService/icons/{pw.pw_name}", os.path.expanduser("~/.face.icon"),
                 os.path.expanduser("~/.face")):
        if os.path.exists(path):
            avatar = "file://" + path
            break
    return {"name": name, "login": pw.pw_name, "avatar": avatar}


def device_info():
    pretty = "Linux"
    try:
        for line in open("/etc/os-release"):
            if line.startswith("PRETTY_NAME="):
                pretty = line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return {"hostname": socket.gethostname(), "os": pretty}


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024


def parse_size(text):
    m = re.match(r"([\d.,]+)\s*([KMG]i?B|B)", text.strip())
    if not m:
        return 0
    val = float(m.group(1).replace(",", "."))
    return int(val * {"B": 1, "KiB": 1024, "KB": 1000, "MiB": 1024 ** 2, "MB": 1000 ** 2,
                      "GiB": 1024 ** 3, "GB": 1000 ** 3}.get(m.group(2), 1))


def installed_apps():
    """Echte Apps (mit Startmenü-Eintrag) samt Herkunft und Größe."""
    entries = [e for e in desktop.all_entries().values()
               if not e.hidden and e.f.get("Type") == "Application" and not e.id.startswith("easylinux-")]
    apps, by_file = [], {}
    for e in entries:
        if "X-EasyLinux-AppImage" in e.f:
            path = e.f["X-EasyLinux-AppImage"]
            size = os.path.getsize(path) if os.path.exists(path) else 0
            apps.append({"name": e.name, "icon": e.icon, "source": "appimage", "ident": e.path,
                         "kind": "AppImage", "bytes": size})
        elif "/flatpak/exports/" in e.path:
            apps.append({"name": e.name, "icon": e.icon, "source": "flatpak", "ident": e.id,
                         "kind": "Flatpak", "bytes": 0})
        else:
            # Umbenannte Kopien in /usr/local gehören zum Original in /usr/share
            original = os.path.join("/usr/share/applications", os.path.basename(e.path))
            by_file[original if os.path.exists(original) else e.path] = e
    # Besitzer-Pakete in einem Rutsch bestimmen
    owners = {}
    if by_file:
        out = subprocess.run(["pacman", "-Qo", *by_file], capture_output=True, text=True,
                             env=dict(os.environ, LANG="C")).stdout
        for line in out.splitlines():
            m = re.match(r"(\S+) is owned by (\S+) ", line)
            if m:
                owners[m.group(1)] = m.group(2)
    pkgs = {}
    for path, e in by_file.items():
        pkg = owners.get(path)
        if not pkg or pkg in PROTECTED:
            continue
        # Ein Paket mit mehreren Einträgen (z. B. KDE Connect) nur einmal zeigen
        if pkg not in pkgs or len(e.name) < len(pkgs[pkg]["name"]):
            pkgs[pkg] = {"name": e.name, "icon": e.icon, "source": "pacman", "ident": pkg,
                         "kind": "Systempaket", "bytes": 0}
    if pkgs:
        info = subprocess.run(["pacman", "-Qi", *pkgs], capture_output=True, text=True,
                              env=dict(os.environ, LANG="C")).stdout
        for block in info.split("\n\n"):
            name = re.search(r"^Name\s*:\s*(\S+)", block, re.M)
            size = re.search(r"^Installed Size\s*:\s*(.+)$", block, re.M)
            if name and size and name.group(1) in pkgs:
                pkgs[name.group(1)]["bytes"] = parse_size(size.group(1))
    if any(a["source"] == "flatpak" for a in apps):
        out = subprocess.run(["flatpak", "list", "--app", "--columns=application,size"],
                             capture_output=True, text=True).stdout
        sizes = dict(line.split("\t", 1) for line in out.splitlines() if "\t" in line)
        for a in apps:
            if a["source"] == "flatpak":
                a["bytes"] = parse_size(sizes.get(a["ident"], "0").replace("\xa0", " "))
    result = apps + list(pkgs.values())
    for a in result:
        a["size"] = human(a["bytes"]) if a["bytes"] else ""
    return sorted(result, key=lambda a: a["name"].lower())


class Backend(QObject):
    appsChanged = Signal()
    message = Signal(str, bool)
    navigate = Signal(str)

    def __init__(self):
        super().__init__()
        self._apps, self._loading = [], False

    @Property("QVariantList", constant=True)
    def categories(self):
        return [{"key": k, "title": t, "icon": i, "subtitle": s} for k, t, i, s in CATEGORIES]

    @Slot(str, result="QVariantList")
    def entries(self, category):
        return [self._entry(e) for e in ENTRIES if e[0] == category and available(e[4])]

    @Slot(str, result="QVariantMap")
    def entryFor(self, target):
        """Eintrag zu einem Ziel (z. B. „kcm_kscreen“) – für Aufrufe von außen."""
        if target == "kcm_kscreen":  # „Anzeige einrichten“ von KDE → unsere Bildschirm-Seite
            target = "page:display"
        e = next((e for e in ENTRIES if e[4] == target and available(target)), None)
        return self._entry(e) if e else {}

    @Property("QVariantMap", constant=True)
    def user(self):
        return user_info()

    @Property("QVariantMap", constant=True)
    def device(self):
        return device_info()

    @Slot(str, result="QVariantList")
    def search(self, text):
        words = [w for w in norm(text).split() if w]
        if not words:
            return []
        scored = []
        for e in ENTRIES:
            if not available(e[4]):
                continue
            title, desc, keys = norm(e[1]), norm(e[2]), norm(e[5])
            score = 0
            for w in words:
                if title.startswith(w) or f" {w}" in f" {title}":
                    score += 10
                elif w in title:
                    score += 6
                if any(k.startswith(w) for k in keys.split()):
                    score += 5
                if w in desc:
                    score += 2
                if not (w in title or w in desc or w in keys):
                    score = -1
                    break
            if score > 0:
                scored.append((score, e))
        scored.sort(key=lambda s: -s[0])
        # Gleiche Seite (z. B. Tastatur unter Geräte und unter Zeit & Sprache) nur einmal zeigen
        seen, result = set(), []
        for _, e in scored:
            if e[4] not in seen:
                seen.add(e[4])
                result.append(self._entry(e))
        return result

    @staticmethod
    def _entry(e):
        cat = next(c[1] for c in CATEGORIES if c[0] == e[0])
        return {"title": e[1], "subtitle": e[2], "icon": e[3], "target": e[4], "category": cat, "categoryKey": e[0],
                "external": opens_window(e[4])}

    @Slot(str)
    def open(self, target):
        """Ziele, die nicht im Fenster angezeigt werden: Programme, Aktionen, alte KCMs (eigenes Fenster)."""
        if target.startswith("kcm_"):
            QProcess.startDetached("kcmshell6", [target])
        elif target == "action:panel-edit":
            QProcess.startDetached("qdbus6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.editMode", "true"])
        elif target.startswith("app:"):
            entry = desktop.find(target[4:])
            if entry:
                QProcess.startDetached("kioclient", ["exec", entry.path])
            else:
                self.message.emit("Dieses Programm ist nicht installiert.", False)

    # ---------- Installierte Apps
    @Property("QVariantList", notify=appsChanged)
    def apps(self):
        return self._apps

    @Property(bool, notify=appsChanged)
    def loading(self):
        return self._loading

    @Slot()
    def loadApps(self):
        self._loading = True
        self.appsChanged.emit()

        def work():
            desktop.all_entries.cache_clear()
            apps = installed_apps()
            QTimer.singleShot(0, self, lambda: self._loaded(apps))
        threading.Thread(target=work, daemon=True).start()

    def _loaded(self, apps):
        self._apps, self._loading = apps, False
        self.appsChanged.emit()

    @Slot(str, str, str)
    def uninstall(self, source, ident, name):
        if source == "appimage":
            entry = desktop.parse(ident)
            for path in (entry.get("X-EasyLinux-AppImage"), ident, entry.get("Icon")):
                if path and os.path.isabs(path) and os.path.exists(path):
                    os.remove(path)
            return self._done(0, name)
        proc = QProcess(self)
        proc.finished.connect(lambda code, _s: self._done(code, name, bytes(proc.readAll()).decode(errors="replace")))
        proc.setProcessChannelMode(QProcess.MergedChannels)
        if source == "flatpak":
            proc.start("flatpak", ["uninstall", "-y", "--noninteractive", ident])
        else:
            proc.start("pkexec", ["pacman", "-Rns", "--noconfirm", ident])
        self._proc = proc

    def _done(self, code, name, output=""):
        if code == 0:
            self.message.emit(f"„{name}“ wurde deinstalliert.", True)
        elif code in (126, 127):
            self.message.emit("Abgebrochen.", False)
        elif "required by" in output or "wird benötigt" in output or "breaks dependency" in output:
            self.message.emit(f"„{name}“ wird von anderen Programmen benötigt und kann nicht einzeln entfernt werden.", False)
        else:
            self.message.emit(f"„{name}“ konnte nicht deinstalliert werden.", False)
        self.loadApps()


NAME = "easylinux-settings"


def main():
    page = sys.argv[1] if len(sys.argv) > 1 else "system"
    if single.notify_running(NAME, page.encode()):
        return 0  # läuft schon – dort die gewünschte Seite öffnen
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Einstellungen")
    app.setDesktopFileName("easylinux-settings")
    app.setWindowIcon(QIcon.fromTheme("preferences-system"))
    backend = Backend()
    host = False
    if os.path.exists(KCMHOST):
        try:
            ctypes.CDLL(KCMHOST).easylinux_register_kcmhost()
            host = True
        except OSError as exc:  # z. B. nach einem Qt-Update nicht mehr passend – dann eigene Fenster
            print("kcmhost nicht geladen:", exc, file=sys.stderr)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    display = Display()
    display.message.connect(backend.message)
    engine.rootContext().setContextProperty("display", display)
    snap_assist = SnapAssist()
    engine.rootContext().setContextProperty("snapAssist", snap_assist)
    developer = Developer()
    developer.message.connect(backend.message)
    engine.rootContext().setContextProperty("developer", developer)
    engine.rootContext().setContextProperty("kcmHostAvailable", host)
    engine.rootContext().setContextProperty("startPage", page)
    engine.load(os.path.join(HERE, "Main.qml"))
    if not engine.rootObjects():
        return 1
    window = engine.rootObjects()[0]

    def on_message(msg):
        window.showNormal()
        backend.navigate.emit(msg)

    server = single.listen(NAME, on_message)  # noqa: F841 – muss am Leben bleiben
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
