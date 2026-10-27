"""Seite „Snap Assist“: Einstellungen für den Andock-Assistenten (KWin-Skript easylinux-snapassist).

Die Werte stehen in kwinrc, Gruppe [Script-easylinux-snapassist]; das Skript liest sie bei jedem Andocken.
Ein- und ausgeschaltet wird das Skript selbst (Plugins/easylinux-snapassistEnabled) – und sofort geladen
bzw. beendet, damit es ohne Neuanmeldung wirkt.
"""
import subprocess

from PySide6.QtCore import QObject, Property, Signal, Slot

SCRIPT = "easylinux-snapassist"
SCRIPT_QML = f"/usr/share/kwin/scripts/{SCRIPT}/contents/ui/main.qml"
GROUP = f"Script-{SCRIPT}"
# Schlüssel und Standardwert – müssen zu main.qml des Skripts passen
OPTIONS = {"AllScreens": True, "WhenOccupied": False, "Quarters": True}


def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def read(group, key, default):
    value = run("kreadconfig6", "--file", "kwinrc", "--group", group, "--key", key, "--default", str(default).lower())
    return value == "true"


def write(group, key, value):
    run("kwriteconfig6", "--file", "kwinrc", "--group", group, "--key", key, "--type", "bool", str(value).lower())


def kwin(*args):
    return run("qdbus6", "org.kde.KWin", *args)


class SnapAssist(QObject):
    changed = Signal()

    @Property(bool, notify=changed)
    def enabled(self):
        return read("Plugins", f"{SCRIPT}Enabled", False)

    @Slot(bool)
    def setEnabled(self, on):
        write("Plugins", f"{SCRIPT}Enabled", on)
        loaded = kwin("/Scripting", "org.kde.kwin.Scripting.isScriptLoaded", SCRIPT) == "true"
        if on and not loaded:
            sid = kwin("/Scripting", "org.kde.kwin.Scripting.loadDeclarativeScript", SCRIPT_QML, SCRIPT)
            if sid:
                kwin(f"/Scripting/Script{sid}", "org.kde.kwin.Script.run")
        elif not on and loaded:
            kwin("/Scripting", "org.kde.kwin.Scripting.unloadScript", SCRIPT)
        self.changed.emit()

    @Property("QVariantMap", notify=changed)
    def options(self):
        return {key: read(GROUP, key, default) for key, default in OPTIONS.items()}

    @Slot(str, bool)
    def setOption(self, key, on):
        if key not in OPTIONS:
            return
        write(GROUP, key, on)
        kwin("/KWin", "reconfigure")  # KWin liest kwinrc neu – das Skript sieht den Wert beim nächsten Andocken
        self.changed.emit()
