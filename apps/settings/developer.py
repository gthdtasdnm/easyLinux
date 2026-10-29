"""Seite „Für Entwickler“: eigene Dienste, Server und Skripte an einer Stelle – an/aus, Autostart, Logs.

Die Suche selbst steht in easylinux/myservices.py. Gesucht wird beim Öffnen der Seite und danach alle
paar Sekunden (im Hintergrund), damit neue Dienste von selbst auftauchen. Schalten läuft ebenfalls im
Hintergrund, weil systemd bei Systemdiensten nach dem Passwort fragt.
"""
import os
import threading

from PySide6.QtCore import QObject, QProcess, QTimer, Property, Signal, Slot

from easylinux import myservices


class Developer(QObject):
    changed = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._entries, self._loading, self._scanning = [], False, False
        self._show_hidden = False
        self._new = set()       # in dieser Sitzung neu entdeckt – bleibt markiert, bis die Seite geschlossen wird
        self._by_id = {}

    # ---------- Liste
    @Property("QVariantList", notify=changed)
    def entries(self):
        hidden = set(myservices.load_state()["hidden"])
        rows = []
        for e in self._entries:
            if e["id"] in hidden and not self._show_hidden:
                continue
            row = dict(e, hidden=e["id"] in hidden, new=e["id"] in self._new)
            row.pop("argv", None)  # braucht QML nicht
            rows.append(row)
        return rows

    @Property(int, notify=changed)
    def hiddenCount(self):
        hidden = set(myservices.load_state()["hidden"])
        return sum(1 for e in self._entries if e["id"] in hidden)

    @Property(bool, notify=changed)
    def loading(self):
        return self._loading

    @Property(bool, notify=changed)
    def showHidden(self):
        return self._show_hidden

    @Slot(bool)
    def setShowHidden(self, on):
        self._show_hidden = on
        self.changed.emit()

    @Slot()
    def refresh(self):
        if self._scanning:
            return
        self._scanning = True
        if not self._entries:
            self._loading = True
            self.changed.emit()

        def work():
            try:
                rows = myservices.scan()
            except Exception as exc:  # Suche darf die Einstellungen nie abstürzen lassen
                print("Dienste-Suche fehlgeschlagen:", exc)
                rows = self._entries
            QTimer.singleShot(0, self, lambda: self._loaded(rows))
        threading.Thread(target=work, daemon=True).start()

    def _loaded(self, rows):
        state = myservices.load_state()
        ids = [e["id"] for e in rows if e["kind"] != "loose"]  # lose Programme ändern sich zu oft
        if state["seen"] is not None:
            self._new |= set(ids) - set(state["seen"])
        if state["seen"] is None or set(ids) - set(state["seen"]):
            state["seen"] = sorted(set(state["seen"] or []) | set(ids))
            myservices.save_state(state)
        rows.sort(key=lambda e: (e["project"] == "", e["projectShort"].lower(), e["kind"] == "loose", e["name"].lower()))
        changed = rows != self._entries or self._loading
        self._entries, self._loading, self._scanning = rows, False, False
        self._by_id = {e["id"]: e for e in rows}
        if changed:
            self.changed.emit()

    @Slot()
    def pageClosed(self):
        self._new.clear()

    # ---------- Schalten (im Hintergrund, danach neu suchen)
    def _do(self, entry_id, fn, ok_text, fail_text):
        entry = self._by_id.get(entry_id)
        if not entry:
            return

        def work():
            ok, err = fn(entry)
            if ok:
                text, good = ok_text.format(name=entry["name"]), True
            elif "authoriz" in err.lower() or "authentic" in err.lower() or "dismissed" in err.lower():
                text, good = "Abgebrochen.", False
            else:
                text, good = fail_text.format(name=entry["name"]) + (f" ({err[:160]})" if err else ""), False
            QTimer.singleShot(0, self, lambda: (self.message.emit(text, good), self.refresh()))
        threading.Thread(target=work, daemon=True).start()

    @Slot(str, bool)
    def setRunning(self, entry_id, on):
        self._do(entry_id, lambda e: myservices.set_running(e, on),
                 "„{name}“ wurde " + ("gestartet." if on else "beendet."),
                 "„{name}“ konnte nicht " + ("gestartet" if on else "beendet") + " werden.")

    @Slot(str, bool)
    def setAutostart(self, entry_id, on):
        self._do(entry_id, lambda e: myservices.set_autostart(e, on),
                 "„{name}“ startet " + ("jetzt automatisch." if on else "nicht mehr automatisch."),
                 "Autostart für „{name}“ konnte nicht geändert werden.")

    @Slot(str)
    def restart(self, entry_id):
        self._do(entry_id, myservices.restart, "„{name}“ wurde neu gestartet.",
                 "„{name}“ konnte nicht neu gestartet werden.")

    @Slot(str, str, str, bool)
    def makeService(self, entry_id, name, description, autostart):
        self._do(entry_id, lambda e: myservices.make_service(e, name, description, autostart),
                 f"Dienst „{name}“ wurde eingerichtet.", "Dienst „" + name + "“ konnte nicht eingerichtet werden.")

    @Slot(str, bool)
    def setHidden(self, entry_id, on):
        state = myservices.load_state()
        hidden = set(state["hidden"])
        hidden.add(entry_id) if on else hidden.discard(entry_id)
        state["hidden"] = sorted(hidden)
        myservices.save_state(state)
        if not self.hiddenCount:
            self._show_hidden = False
        self.changed.emit()

    # ---------- Öffnen
    @Slot(int)
    def openPort(self, port):
        QProcess.startDetached("xdg-open", [f"http://localhost:{port}"])

    @Slot(str)
    def openFolder(self, path):
        if os.path.isdir(path):
            QProcess.startDetached("xdg-open", [path])

    @Slot(str)
    def openFile(self, path):
        if os.path.isfile(path):
            QProcess.startDetached("xdg-open", [path])

    @Slot(str)
    def showLog(self, entry_id):
        e = self._by_id.get(entry_id)
        if not e or not e["unit"]:
            return
        unit = e["unit"].replace(".timer", ".service")
        args = ["journalctl", *(["--user"] if e["user"] else []), "-u", unit, "-n", "200", "-f"]
        QProcess.startDetached("konsole", ["--hide-menubar", "-p", f"tabtitle=Protokoll: {e['name']}", "-e", *args])

    # ---------- Coding-Agenten
    @Property(bool, notify=changed)
    def agentHint(self):
        return myservices.agent_hint_enabled()

    @Property(str, notify=changed)
    def agents(self):
        return ", ".join(myservices.agents_installed())

    @Slot(bool)
    def setAgentHint(self, on):
        try:
            myservices.set_agent_hint(on)
            self.message.emit("Coding-Agenten richten neue Dienste jetzt so ein, dass sie hier erscheinen." if on
                              else "Hinweis für Coding-Agenten wurde entfernt.", True)
        except OSError as exc:
            self.message.emit(f"Konnte die Anweisungsdatei nicht ändern: {exc}", False)
        self.changed.emit()
