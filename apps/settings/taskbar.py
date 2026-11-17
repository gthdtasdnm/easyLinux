"""Seite „Taskleiste“ wie bei Windows 11 (Personalisierung › Taskleiste): Ausrichtung, automatisch ausblenden,
Taskleiste auf allen Bildschirmen, wo Apps angezeigt werden, Gruppieren, Sekunden in der Uhr.

Alles über die Skript-Schnittstelle von Plasma (org.kde.PlasmaShell.evaluateScript) in der laufenden Sitzung.
Betroffen sind nur die Leisten am unteren Rand – also die, die easyLinux anlegt.
"""
import json
import os
import subprocess
import time

from PySide6.QtCore import QObject, Property, Signal, Slot

LAYOUT_SH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "user", "90-layout", "apply.sh")

# Hilfsfunktionen, die jedem Skript vorangestellt werden
PRELUDE = """
function bars() { return panels().filter(function (p) { return p.location === "bottom"; }); }
function tasks(p) { var w = p.widgets("org.kde.plasma.icontasks"); return w.length ? w[0] : null; }
function clocks(p) { return p.widgets("org.kde.plasma.digitalclock"); }
"""

READ = PRELUDE + """
var b = bars(), main = b.filter(function (p) { return p.screen === 0; })[0] || b[0];
var r = { found: !!main, screens: screenCount, bars: b.length };
if (main) {
    r.centered = main.widgets("org.kde.plasma.panelspacer").length >= 2;
    r.autohide = main.hiding === "autohide";
    var t = tasks(main);
    if (t) {
        t.currentConfigGroup = ["General"];
        r.currentScreenOnly = t.readConfig("showOnlyCurrentScreen", false) === true || t.readConfig("showOnlyCurrentScreen", false) === "true";
        r.grouping = String(t.readConfig("groupingStrategy", 1)) !== "0";
    }
    var c = clocks(main)[0];
    if (c) { c.currentConfigGroup = ["Appearance"]; r.seconds = String(c.readConfig("showSeconds", 0)) === "2"; }
}
print(JSON.stringify(r));
"""


def evaluate(script):
    try:
        r = subprocess.run(["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript",
                            script], capture_output=True, text=True, timeout=15)
        return r.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def center_script(on):
    """Ausrichtung wie Windows 11 (Mitte) oder Windows 10 (links): zwei dehnbare Platzhalter um Start + Apps.
    Plasma hängt neue Elemente immer hinten an – die gewünschte Reihenfolge gibt das Skript zurück,
    sie wird bei kurz beendetem Plasma in die Konfiguration geschrieben."""
    return PRELUDE + """
var orders = {};
bars().forEach(function (p) {
    p.widgets("org.kde.plasma.panelspacer").forEach(function (w) { w.remove(); });
    if (!%s) return;
    var t = tasks(p);
    var ids = p.widgets().map(function (w) { return w.id; }).filter(function (id) {
        return p.widgets("org.kde.plasma.panelspacer").every(function (s) { return s.id !== id; }); });
    var first = p.addWidget("org.kde.plasma.panelspacer"), second = p.addWidget("org.kde.plasma.panelspacer");
    var order = [first.id];
    ids.forEach(function (id) { order.push(id); if (t && id === t.id) order.push(second.id); });
    orders[p.id] = order.join(";");
});
print(JSON.stringify(orders));
""" % ("true" if on else "false")


def restart_plasma_with(orders):
    """Plasma beenden, Reihenfolge schreiben, Plasma starten (wie user/95-rightclick)."""
    run = lambda *a: subprocess.run(a, capture_output=True, timeout=30)  # noqa: E731
    run("systemctl", "--user", "stop", "plasma-plasmashell.service")
    for cid, order in orders.items():
        run("kwriteconfig6", "--file", "plasma-org.kde.plasma.desktop-appletsrc", "--group", "Containments",
            "--group", str(cid), "--group", "General", "--key", "AppletOrder", order)
    run("systemctl", "--user", "start", "plasma-plasmashell.service")


class Taskbar(QObject):
    changed = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._state = {}

    @Slot()
    def refresh(self):
        try:
            self._state = json.loads(evaluate(READ) or "{}")
        except ValueError:
            self._state = {}
        self.changed.emit()

    @Property("QVariantMap", notify=changed)
    def state(self):
        return self._state

    def _apply(self, script, text=""):
        evaluate(PRELUDE + script)
        self.refresh()
        if text:
            self.message.emit(text, True)

    @Slot(bool)
    def setCentered(self, on):
        try:
            orders = json.loads(evaluate(center_script(on)) or "{}")
        except ValueError:
            orders = {}
        if orders:
            restart_plasma_with(orders)  # Taskleiste verschwindet dafür ca. 2 Sekunden
            time.sleep(3)
        self.refresh()

    @Slot(bool)
    def setAutohide(self, on):
        self._apply('bars().forEach(function (p) { p.hiding = "%s"; });' % ("autohide" if on else "none"))

    @Slot(bool)
    def setAllScreens(self, on):
        if on:
            subprocess.run(["bash", LAYOUT_SH], capture_output=True, timeout=30)
            self.refresh()
        else:
            self._apply('bars().forEach(function (p) { if (p.screen !== 0) p.remove(); });')

    @Slot(bool)
    def setCurrentScreenOnly(self, on):
        self._apply("""bars().forEach(function (p) { var t = tasks(p); if (t) {
            t.currentConfigGroup = ["General"]; t.writeConfig("showOnlyCurrentScreen", %s); } });""" % str(on).lower())

    @Slot(bool)
    def setGrouping(self, on):
        self._apply("""bars().forEach(function (p) { var t = tasks(p); if (t) {
            t.currentConfigGroup = ["General"]; t.writeConfig("groupingStrategy", %d); } });""" % (1 if on else 0))

    @Slot(bool)
    def setSeconds(self, on):
        self._apply("""bars().forEach(function (p) { clocks(p).forEach(function (c) {
            c.currentConfigGroup = ["Appearance"]; c.writeConfig("showSeconds", %d); }); });""" % (2 if on else 0))

    @Slot()
    def editMode(self):
        subprocess.Popen(["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.editMode", "true"])


if __name__ == "__main__":
    print(evaluate(READ))
