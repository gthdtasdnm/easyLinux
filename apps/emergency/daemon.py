#!/usr/bin/env python3
"""Notfall-Dienst: Strg+Alt+Entf hilft auch dann, wenn die Oberfläche hängt.

Liest die Tastaturen direkt (evdev) – unabhängig von KWin/Plasma. Bei Strg+Alt+Entf wartet er
kurz, ob der Strg+Alt+Entf-Bildschirm der Sitzung erscheint (er schreibt eine Quittung nach
/run/user/<uid>/easylinux-sessionmenu.ack). Bleibt die Quittung aus – oder wird die Kombination
innerhalb weniger Sekunden zweimal gedrückt –, wechselt der Dienst auf eine Textkonsole und
zeigt dort das Notfall-Menü (menu.py).
"""
import glob
import os
import select
import struct
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
EVENT = struct.Struct("llHHi")
EV_KEY = 1
CTRL, ALT, DEL = {29, 97}, {56, 100}, {111}
MENU_VT = 9
ACK_WAIT = 3.0       # so lange darf der Strg+Alt+Entf-Bildschirm brauchen
DOUBLE_PRESS = 8.0   # zweimal innerhalb dieser Zeit → Notfall-Menü erzwingen


def log(msg):
    print(msg, flush=True)


def keyboards():
    """Eingabegeräte, die eine Entf-Taste haben (= Tastaturen)."""
    found = []
    for dev in glob.glob("/sys/class/input/event*"):
        try:
            caps = open(os.path.join(dev, "device/capabilities/key")).read().split()
        except OSError:
            continue
        bits = int("".join(f"{int(w, 16):016x}" for w in caps), 16) if caps else 0
        if bits >> 111 & 1 and bits >> 29 & 1:
            found.append("/dev/input/" + os.path.basename(dev))
    return found


def active_session():
    """(uid, vt) der aktiven grafischen Benutzersitzung auf seat0 – oder None."""
    def prop(*args):
        return subprocess.run(["loginctl", *args], capture_output=True, text=True).stdout.strip()
    sid = prop("show-seat", "seat0", "-p", "ActiveSession", "--value")
    if not sid:
        return None
    info = dict(line.split("=", 1) for line in prop("show-session", sid, "-p", "Class", "-p", "Type",
                                                     "-p", "User", "-p", "VTNr").splitlines() if "=" in line)
    if info.get("Class") != "user" or info.get("Type") not in ("wayland", "x11"):
        return None
    return int(info["User"]), int(info.get("VTNr") or 0)


def acked_since(uid, t):
    try:
        return os.path.getmtime(f"/run/user/{uid}/easylinux-sessionmenu.ack") >= t - 0.5
    except OSError:
        return False


def show_menu(uid, vt):
    log(f"Notfall-Menü für Benutzer {uid} (zurück auf VT {vt})")
    env = dict(os.environ, TERM="linux")
    subprocess.run(["openvt", "-c", str(MENU_VT), "-s", "-f", "-w", "--",
                    sys.executable, os.path.join(HERE, "menu.py"), str(uid), str(vt)], env=env)
    if vt:
        subprocess.run(["chvt", str(vt)])


def main():
    fds, last_scan = {}, 0
    held = set()
    last_press = 0.0
    while True:
        if time.monotonic() - last_scan > 5:  # neue Tastaturen (USB) erkennen
            for path in keyboards():
                if path not in fds.values():
                    try:
                        fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = path
                    except OSError:
                        pass
            last_scan = time.monotonic()
        ready, _, _ = select.select(list(fds), [], [], 2.0)
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:
                os.close(fd)
                del fds[fd]
                held.clear()
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, etype, code, value = EVENT.unpack_from(data, i)
                if etype != EV_KEY:
                    continue
                if value == 0:
                    held.discard(code)
                    continue
                if value != 1:
                    continue  # Tastenwiederholung
                held.add(code)
                if code in DEL and held & CTRL and held & ALT:
                    now = time.time()
                    double = now - last_press < DOUBLE_PRESS
                    last_press = now
                    session = active_session()
                    if not session:
                        continue
                    uid, vt = session
                    if not double:
                        time.sleep(ACK_WAIT)
                        if acked_since(uid, now):
                            continue  # Oberfläche hat reagiert
                    held.clear()
                    show_menu(uid, vt)
                    last_press = 0.0
                    # Tasten, die während des Menüs gedrückt wurden, verwerfen
                    for f in fds:
                        try:
                            while os.read(f, 4096):
                                pass
                        except OSError:
                            pass


if __name__ == "__main__":
    main()
