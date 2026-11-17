"""easyLinux Fotos – Bilder ansehen wie mit „Fotos“ bei Windows: ein Bild groß, Vor/Zurück durch den Ordner,
Zoomen, Drehen, Löschen, als Hintergrund festlegen.

    easylinux-photos [Datei|Ordner]
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from PySide6.QtCore import QDateTime, QFile, QFileInfo, QLocale, QObject, QUrl, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon, QImageReader
from PySide6.QtQml import QQmlApplicationEngine

HERE = os.path.dirname(os.path.abspath(__file__))
EXTS = {"." + bytes(f).decode().lower() for f in QImageReader.supportedImageFormats()} | {".jpg", ".jpeg"}
EXTS -= {".pdf", ".svgz", ".xcf"}


def natural_key(name):
    """„Bild 2“ vor „Bild 10“ – wie im Datei-Explorer."""
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", name)]


def list_images(folder):
    try:
        names = os.listdir(folder)
    except OSError:
        return []
    files = [n for n in names if os.path.splitext(n)[1].lower() in EXTS and not n.startswith(".")]
    return [os.path.join(folder, n) for n in sorted(files, key=natural_key)]


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".", ",")
        n /= 1024


class Photos(QObject):
    changed = Signal()
    message = Signal(str)

    def __init__(self, path):
        super().__init__()
        self._files, self._index = [], -1
        self.open(path)

    @Slot(str)
    def open(self, path):
        if path.startswith("file:"):
            path = QUrl(path).toLocalFile()
        path = os.path.abspath(os.path.expanduser(path)) if path else ""
        folder = path if os.path.isdir(path) else os.path.dirname(path)
        self._files = list_images(folder) if folder else []
        if path and not os.path.isdir(path) and path not in self._files:
            self._files.insert(0, path)  # z. B. Dateiendung, die der Ordner-Filter nicht kennt
        self._index = self._files.index(path) if path in self._files else (0 if self._files else -1)
        self.changed.emit()

    @Property(int, notify=changed)
    def count(self):
        return len(self._files)

    @Property(int, notify=changed)
    def index(self):
        return self._index

    @Property("QStringList", notify=changed)
    def urls(self):
        return [QUrl.fromLocalFile(f).toString() for f in self._files]

    @Property(str, notify=changed)
    def current(self):
        return self._files[self._index] if self._index >= 0 else ""

    @Property(str, notify=changed)
    def currentUrl(self):
        return QUrl.fromLocalFile(self.current).toString() if self.current else ""

    @Property(str, notify=changed)
    def name(self):
        return os.path.basename(self.current)

    @Property(bool, notify=changed)
    def animated(self):
        return os.path.splitext(self.current)[1].lower() in (".gif", ".apng")

    @Slot(int)
    def go(self, index):
        if self._files:
            self._index = index % len(self._files)
            self.changed.emit()

    @Slot()
    def next(self):
        self.go(self._index + 1)

    @Slot()
    def previous(self):
        self.go(self._index - 1)

    @Slot(result="QVariantList")
    def info(self):
        """Dateiinformationen für die Seitenleiste."""
        f = self.current
        if not f:
            return []
        fi = QFileInfo(f)
        reader = QImageReader(f)
        size = reader.size()
        rows = [("Dateiname", fi.fileName()), ("Ordner", fi.absolutePath()),
                ("Größe", human(fi.size())),
                ("Geändert", QLocale(QLocale.German).toString(fi.lastModified(), "dd.MM.yyyy HH:mm"))]
        if size.isValid():
            rows.insert(2, ("Abmessungen", f"{size.width()} × {size.height()} Pixel"))
        taken = reader.text("DateTimeOriginal") or reader.text("DateTime")
        if taken:
            dt = QDateTime.fromString(taken.strip(), "yyyy:MM:dd HH:mm:ss")
            if dt.isValid():
                rows.insert(0, ("Aufgenommen", QLocale(QLocale.German).toString(dt, "dd.MM.yyyy HH:mm")))
        model = reader.text("Model")
        if model:
            rows.append(("Kamera", model.strip()))
        return [{"label": k, "value": v} for k, v in rows]

    @Slot()
    def delete(self):
        """In den Papierkorb verschieben (wie bei Windows; nichts wird endgültig gelöscht)."""
        f = self.current
        if not f:
            return
        if QFile.moveToTrash(f):
            del self._files[self._index]
            if self._index >= len(self._files):
                self._index = len(self._files) - 1
            self.message.emit(f"„{os.path.basename(f)}“ wurde in den Papierkorb verschoben.")
            self.changed.emit()
        else:
            self.message.emit("Die Datei konnte nicht gelöscht werden.")

    @Slot()
    def setWallpaper(self):
        if not self.current:
            return
        r = subprocess.run(["plasma-apply-wallpaperimage", self.current], capture_output=True)
        self.message.emit("Als Hintergrund festgelegt." if r.returncode == 0 else "Hintergrund konnte nicht geändert werden.")

    @Slot()
    def showInFolder(self):
        if self.current:
            subprocess.Popen(["dolphin", "--select", self.current], start_new_session=True)

    @Slot()
    def openWith(self):
        if self.current:
            subprocess.Popen(["kioclient", "openWith", self.current], start_new_session=True,
                             stderr=subprocess.DEVNULL)

    @Slot()
    def copy(self):
        from PySide6.QtCore import QMimeData
        data = QMimeData()
        data.setUrls([QUrl.fromLocalFile(self.current)])
        data.setImageData(QImageReader(self.current).read())
        QGuiApplication.clipboard().setMimeData(data)
        self.message.emit("Bild kopiert.")


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Fotos")
    app.setDesktopFileName("easylinux-photos")
    app.setWindowIcon(QIcon.fromTheme("image-x-generic"))
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    photos = Photos(args[0] if args else os.path.expanduser("~/Bilder"))
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("photos", photos)
    engine.load(os.path.join(HERE, "Main.qml"))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        assert natural_key("Bild 2.jpg") < natural_key("Bild 10.jpg")
        assert ".jpg" in EXTS and ".png" in EXTS
        print("ok")
        sys.exit(0)
    sys.exit(main())
