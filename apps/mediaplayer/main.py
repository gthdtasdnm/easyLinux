"""easyLinux Medienplayer – Videos und Musik abspielen wie mit dem Medienplayer von Windows 11:
großes Bild, Steuerleiste unten, die sich beim Zuschauen ausblendet, Weiter/Zurück durch den Ordner.

    easylinux-mediaplayer [Datei …]
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from PySide6.QtCore import QObject, QUrl, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

HERE = os.path.dirname(os.path.abspath(__file__))
VIDEO = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".mpg", ".mpeg", ".wmv", ".flv", ".ogv", ".3gp", ".ts", ".m2ts"}
AUDIO = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".wav", ".m4a", ".aac", ".wma", ".aiff", ".ape", ".mka"}


def natural_key(name):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", name)]


def kind(path):
    ext = os.path.splitext(path)[1].lower()
    return "video" if ext in VIDEO else "audio" if ext in AUDIO else ""


def playlist_for(path):
    """Eine Datei geöffnet → alle Dateien derselben Art im Ordner (Folgen einer Serie, Alben)."""
    k = kind(path)
    folder = os.path.dirname(path)
    try:
        names = sorted((n for n in os.listdir(folder) if not n.startswith(".")), key=natural_key)
    except OSError:
        return [path]
    files = [os.path.join(folder, n) for n in names if kind(n) == k] if k else []
    return files if path in files else [path]


class Player(QObject):
    changed = Signal()

    def __init__(self, paths):
        super().__init__()
        self._files, self._index = [], -1
        self.setFiles(paths)

    def setFiles(self, paths):
        paths = [QUrl(p).toLocalFile() if p.startswith("file:") else os.path.abspath(p) for p in paths]
        paths = [p for p in paths if os.path.isfile(p)]
        self._files = playlist_for(paths[0]) if len(paths) == 1 else paths
        self._index = self._files.index(paths[0]) if paths else -1
        self.changed.emit()

    @Slot("QVariantList")
    def openUrls(self, urls):
        self.setFiles([u.toString() if hasattr(u, "toString") else str(u) for u in urls])

    @Property(str, notify=changed)
    def source(self):
        return QUrl.fromLocalFile(self._files[self._index]).toString() if self._index >= 0 else ""

    @Property(str, notify=changed)
    def title(self):
        if self._index < 0:
            return ""
        return os.path.splitext(os.path.basename(self._files[self._index]))[0]

    @Property(bool, notify=changed)
    def isAudio(self):
        return self._index >= 0 and kind(self._files[self._index]) == "audio"

    @Property(int, notify=changed)
    def index(self):
        return self._index

    @Property(int, notify=changed)
    def count(self):
        return len(self._files)

    @Property("QStringList", notify=changed)
    def titles(self):
        return [os.path.splitext(os.path.basename(f))[0] for f in self._files]

    @Slot(result=bool)
    def next(self):
        if self._index + 1 < len(self._files):
            self._index += 1
            self.changed.emit()
            return True
        return False

    @Slot()
    def previous(self):
        if self._index > 0:
            self._index -= 1
            self.changed.emit()

    @Slot(int)
    def go(self, i):
        if 0 <= i < len(self._files):
            self._index = i
            self.changed.emit()

    @Slot(float, result=str)
    def time(self, ms):
        s = int(ms / 1000)
        h, rest = divmod(s, 3600)
        m, s = divmod(rest, 60)
        return f"{h}:{m:02}:{s:02}" if h else f"{m}:{s:02}"


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Medienplayer")
    app.setDesktopFileName("easylinux-mediaplayer")
    app.setWindowIcon(QIcon.fromTheme("multimedia-player"))
    player = Player([a for a in sys.argv[1:] if not a.startswith("-")])
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("playlist", player)
    engine.load(os.path.join(HERE, "Main.qml"))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        assert kind("a.MKV") == "video" and kind("b.flac") == "audio" and kind("c.txt") == ""
        assert natural_key("Folge 2") < natural_key("Folge 10")
        p = Player([])
        assert p.time(3725000) == "1:02:05" and p.time(65000) == "1:05"
        print("ok")
        sys.exit(0)
    sys.exit(main())
