"""Bildschirm-Seite wie bei Windows 11: duplizieren/erweitern, Hauptbildschirm, Auflösung, Skalierung,
Ausrichtung und Bildwiederholrate. Gelesen und gesetzt wird über kscreen-doctor.

Nach jeder Änderung fragt die Seite wie Windows „Beibehalten?“ – ohne Antwort wird nach 15 Sekunden
der vorherige Zustand wiederhergestellt (falls der Bildschirm z. B. schwarz bleibt).
"""
import json
import os
import subprocess

from PySide6.QtCore import QObject, QTimer, Property, Signal, Slot

ROTATIONS = {1: "none", 2: "left", 4: "inverted", 8: "right"}
ROTATION_NAMES = [("none", "Querformat"), ("left", "Hochformat"), ("inverted", "Querformat (gedreht)"),
                  ("right", "Hochformat (gedreht)")]
SCALES = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]
REVERT_SECONDS = 15


def doctor(*args):
    try:
        env = {k: v for k, v in os.environ.items() if k != "QT_QPA_PLATFORM"}  # braucht die echte Sitzung
        return subprocess.run(["kscreen-doctor", *args], capture_output=True, text=True, timeout=15, env=env)
    except (OSError, subprocess.TimeoutExpired):
        return None


def read_outputs():
    r = doctor("-j")
    try:
        data = json.loads(r.stdout) if r else {}
    except ValueError:
        data = {}
    return [o for o in data.get("outputs", []) if o.get("connected")]


def pretty_name(o):
    kind = "Integrierter Bildschirm" if o["name"].startswith(("eDP", "LVDS", "DSI")) else "Bildschirm"
    return f"{kind} ({o['name']})"


def describe(outputs):
    """Für die Oberfläche aufbereitet; Nummern wie bei Windows (1 = Hauptbildschirm)."""
    ordered = sorted(outputs, key=lambda o: (not o["enabled"], o.get("priority") or 99, o["pos"]["x"]))
    result = []
    for number, o in enumerate(ordered, 1):
        modes = o.get("modes", [])
        current = next((m for m in modes if m["id"] == o.get("currentModeId")), None)
        preferred = set(o.get("preferredModes") or [])
        # Auflösungen (größte zuerst), je Auflösung die Bildwiederholraten
        sizes = {}
        for m in modes:
            key = (m["size"]["width"], m["size"]["height"])
            sizes.setdefault(key, []).append(m)
        best = next((m for m in modes if m["id"] in preferred), None)
        resolutions = []
        for (w, h), ms in sorted(sizes.items(), key=lambda kv: kv[0][0] * kv[0][1], reverse=True):
            rec = best is not None and (w, h) == (best["size"]["width"], best["size"]["height"])
            rates = sorted(ms, key=lambda m: -m["refreshRate"])
            resolutions.append({
                "text": f"{w} × {h}" + (" (empfohlen)" if rec else ""),
                "width": w, "height": h,
                "rates": [{"text": f"{m['refreshRate']:.2f} Hz".replace(".00 Hz", " Hz").replace(".", ","),
                           "id": m["id"]} for m in rates],
            })
        geo = o.get("size") or {}
        result.append({
            "id": o["id"], "name": o["name"], "number": number, "title": pretty_name(o),
            "enabled": o["enabled"], "primary": o.get("priority") == 1 and o["enabled"],
            "mirrorOf": o.get("replicationSource") or 0,
            "x": o["pos"]["x"], "y": o["pos"]["y"],
            "width": geo.get("width") or (current["size"]["width"] if current else 1920),
            "height": geo.get("height") or (current["size"]["height"] if current else 1080),
            "scale": o.get("scale") or 1.0,
            "rotation": ROTATIONS.get(o.get("rotation"), "none"),
            "modeId": o.get("currentModeId") or "",
            "resolution": f"{current['size']['width']}x{current['size']['height']}" if current else "",
            "resolutions": resolutions,
        })
    return result


def logical_width(o):
    """Breite in Bildschirmkoordinaten (Wayland: durch die Skalierung geteilt, Hochformat vertauscht)."""
    w = o["height"] if o["rotation"] in ("left", "right") else o["width"]
    return round(w / (o["scale"] or 1))


def state_args(outputs):
    """kscreen-doctor-Argumente, die genau diesen Zustand wiederherstellen."""
    args = []
    by_id = {o["id"]: o["name"] for o in outputs}
    for o in outputs:
        n = o["name"]
        if not o["enabled"]:
            args.append(f"output.{n}.disable")
            continue
        args += [f"output.{n}.enable", f"output.{n}.mode.{o['currentModeId']}", f"output.{n}.scale.{o['scale']}",
                 f"output.{n}.rotation.{ROTATIONS.get(o['rotation'], 'none')}",
                 f"output.{n}.position.{o['pos']['x']},{o['pos']['y']}"]
        if o.get("priority"):
            args.append(f"output.{n}.priority.{o['priority']}")
        src = o.get("replicationSource") or 0
        args.append(f"output.{n}.mirror.{by_id[src]}" if src in by_id else f"output.{n}.mirror.none")
    return args


class Display(QObject):
    changed = Signal()
    pendingChanged = Signal()
    message = Signal(str, bool)

    def __init__(self):
        super().__init__()
        self._raw = []
        self._outputs = []
        self._undo = None
        self._left = 0
        self._timer = QTimer(self, interval=1000)
        self._timer.timeout.connect(self._tick)

    @Property("QVariantList", notify=changed)
    def outputs(self):
        return self._outputs

    @Property(str, notify=changed)
    def mode(self):
        """„extend“, „duplicate“ oder „only:<Name>“ – wie das Windows-Auswahlfeld „Mehrere Bildschirme“."""
        on = [o for o in self._outputs if o["enabled"]]
        if len(on) == 1 and len(self._outputs) > 1:
            return "only:" + on[0]["name"]
        if len(on) > 1 and all(o["mirrorOf"] or o["primary"] for o in on) and any(o["mirrorOf"] for o in on):
            return "duplicate"
        return "extend"

    @Property(int, notify=pendingChanged)
    def secondsLeft(self):
        return self._left if self._undo else 0

    @Slot()
    def refresh(self):
        self._raw = read_outputs()
        self._outputs = describe(self._raw)
        self.changed.emit()

    def _apply(self, args):
        if self._undo is None:  # bei mehreren Änderungen hintereinander auf den ersten Zustand zurück
            self._undo = state_args(self._raw)
        r = doctor(*args)
        if r is None or r.returncode != 0:
            self.message.emit("Die Einstellung konnte nicht übernommen werden.", False)
        self.refresh()
        self._left = REVERT_SECONDS
        self._timer.start()
        self.pendingChanged.emit()

    def _tick(self):
        self._left -= 1
        if self._left <= 0:
            self.revert()
        else:
            self.pendingChanged.emit()

    @Slot()
    def keep(self):
        self._undo = None
        self._timer.stop()
        self.pendingChanged.emit()

    @Slot()
    def revert(self):
        undo, self._undo = self._undo, None
        self._timer.stop()
        if undo:
            doctor(*undo)
        self.refresh()
        self.pendingChanged.emit()

    def _name(self, output_id):
        return next((o["name"] for o in self._outputs if o["id"] == output_id), None)

    @Slot(str)
    def setMode(self, mode):
        outs = self._outputs
        if len(outs) < 2 or mode == self.mode:
            return
        primary = next((o for o in outs if o["primary"]), outs[0])
        if mode == "duplicate":
            args = [f"output.{primary['name']}.enable"]
            for o in outs:
                if o is not primary:
                    args += [f"output.{o['name']}.enable", f"output.{o['name']}.mirror.{primary['name']}"]
        elif mode == "extend":
            # Nebeneinander von links nach rechts, Hauptbildschirm zuerst
            args, x = [], 0
            for o in sorted(outs, key=lambda o: (not o["primary"], o["x"])):
                args += [f"output.{o['name']}.enable", f"output.{o['name']}.mirror.none",
                         f"output.{o['name']}.position.{x},0"]
                x += logical_width(o)
        elif mode.startswith("only:"):
            name = mode[5:]
            args = [f"output.{name}.enable", f"output.{name}.mirror.none", f"output.{name}.position.0,0",
                    f"output.{name}.priority.1"]
            args += [f"output.{o['name']}.disable" for o in outs if o["name"] != name]
        else:
            return
        self._apply(args)

    @Slot(int)
    def setPrimary(self, output_id):
        name = self._name(output_id)
        if name:
            self._apply([f"output.{name}.priority.1"])
            self.keep()  # harmlos – keine Rückfrage nötig

    @Slot(int, str)
    def setModeId(self, output_id, mode_id):
        name = self._name(output_id)
        if name and mode_id:
            self._apply([f"output.{name}.mode.{mode_id}"])

    @Slot(int, float)
    def setScale(self, output_id, scale):
        name = self._name(output_id)
        if name:
            self._apply([f"output.{name}.scale.{scale:g}"])

    @Slot(int, str)
    def setRotation(self, output_id, rotation):
        name = self._name(output_id)
        if name:
            self._apply([f"output.{name}.rotation.{rotation}"])

    @Property("QVariantList", constant=True)
    def rotations(self):
        return [{"value": v, "text": t} for v, t in ROTATION_NAMES]

    @Property("QVariantList", constant=True)
    def scales(self):
        return [{"value": s, "text": f"{round(s * 100)} %"} for s in SCALES]
