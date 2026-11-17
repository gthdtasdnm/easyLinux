"""Seite „Datum & Uhrzeit“ wie bei Windows 11: Uhrzeit automatisch stellen, Zeitzone, Datum/Uhrzeit von Hand.
(Heißt clock.py, weil datetime.py Pythons eigenes Modul verdecken würde.)

Über timedatectl (systemd-timedated). Änderungen fragen über Polkit einmal nach dem Administrator-Passwort.
"""
import re
import subprocess
import threading

from PySide6.QtCore import QObject, QTimer, Property, Signal, Slot


def _run(*args, timeout=60):
    try:
        r = subprocess.run(["timedatectl", *args], capture_output=True, text=True, timeout=timeout,
                           env={"LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"})
        return r.returncode, r.stdout, r.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, "", str(exc)


def valid_datetime(date, time):
    """„17.11.2026“, „14:05“ → „2026-11-17 14:05:00“ oder "" bei falscher Eingabe."""
    d = re.fullmatch(r"\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*", date)
    t = re.fullmatch(r"\s*(\d{1,2}):(\d{2})\s*", time)
    if not d or not t:
        return ""
    day, month, year = map(int, d.groups())
    hour, minute = map(int, t.groups())
    if not (1 <= day <= 31 and 1 <= month <= 12 and 1970 <= year <= 2100 and hour < 24 and minute < 60):
        return ""
    return f"{year:04}-{month:02}-{day:02} {hour:02}:{minute:02}:00"


class DateTime(QObject):
    changed = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._info = {}
        self._zones = []

    @Slot()
    def refresh(self):
        def work():
            _, out, _ = _run("show")
            info = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
            zones = self._zones or _run("list-timezones")[1].split()
            QTimer.singleShot(0, self, lambda: self._loaded(info, zones))
        threading.Thread(target=work, daemon=True).start()

    def _loaded(self, info, zones):
        self._info, self._zones = info, zones
        self.changed.emit()

    @Property(bool, notify=changed)
    def automatic(self):
        return self._info.get("NTP") == "yes"

    @Property(bool, notify=changed)
    def synchronized(self):
        return self._info.get("NTPSynchronized") == "yes"

    @Property(str, notify=changed)
    def timezone(self):
        return self._info.get("Timezone", "")

    @Property("QVariantList", notify=changed)
    def timezones(self):
        return self._zones

    def _change(self, args, ok_text):
        def work():
            code, _, err = _run(*args)
            QTimer.singleShot(0, self, lambda: self._changed(code, err, ok_text))
        threading.Thread(target=work, daemon=True).start()

    def _changed(self, code, err, ok_text):
        if code == 0:
            self.message.emit(ok_text, True)
        elif "authoriz" in err.lower() or "authentication" in err.lower():
            self.message.emit("Abgebrochen.", False)
        else:
            self.message.emit(f"Das hat nicht geklappt: {err[:160]}", False)
        self.refresh()

    @Slot(bool)
    def setAutomatic(self, on):
        self._change(["set-ntp", "true" if on else "false"],
                     "Die Uhrzeit wird automatisch gestellt." if on else "Automatisches Stellen ist aus.")

    @Slot(str)
    def setTimezone(self, zone):
        if zone in self._zones and zone != self.timezone:
            self._change(["set-timezone", zone], f"Zeitzone ist jetzt {zone}.")

    @Slot(str, str, result=bool)
    def setManual(self, date, time):
        value = valid_datetime(date, time)
        if not value:
            self.message.emit("Bitte das Datum wie 17.11.2026 und die Uhrzeit wie 14:05 eingeben.", False)
            return False
        self._change(["set-time", value], "Datum und Uhrzeit wurden geändert.")
        return True

    @Slot()
    def syncNow(self):
        # Zeitdienst neu anstoßen: kurz aus- und wieder einschalten (wie „Jetzt synchronisieren“)
        def work():
            _run("set-ntp", "false")
            code, _, err = _run("set-ntp", "true")
            QTimer.singleShot(0, self, lambda: self._changed(code, err, "Die Uhrzeit wird mit dem Internet abgeglichen."))
        threading.Thread(target=work, daemon=True).start()


if __name__ == "__main__":
    assert valid_datetime("17.11.2026", "14:05") == "2026-11-17 14:05:00"
    assert valid_datetime("1.2.2026", "7:00") == "2026-02-01 07:00:00"
    assert valid_datetime("32.11.2026", "14:05") == ""
    assert valid_datetime("17.11.2026", "24:00") == ""
    assert valid_datetime("abc", "14:05") == ""
    print("ok")
