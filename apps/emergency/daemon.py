#!/usr/bin/env python3
"""Notfall-Dienst: Strg+Alt+Entf hilft auch dann, wenn die Oberfläche hängt.

Liest die Tastaturen direkt (evdev) – unabhängig von KWin/Plasma. Bei Strg+Alt+Entf wartet er
kurz, ob der Strg+Alt+Entf-Bildschirm der Sitzung erscheint (er schreibt eine Quittung nach
/run/user/<uid>/easylinux-sessionmenu.ack, beim Schließen steht „closed“ darin) und ob KWin noch antwortet.
Antwortet KWin nicht, bleibt die Quittung aus (außer bei gesperrtem Bildschirm, dort nimmt
Plasma keine Tastenkürzel an) oder wird die Kombination bei offenem Strg+Alt+Entf-Bildschirm
erneut gedrückt (das Bild hängt also), wechselt der Dienst auf eine Textkonsole und zeigt das Notfall-Menü (menu.py).
"""
import glob
import os
import select
import socket
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
PING_WAIT = 2.0      # so lange darf KWin für eine Antwort brauchen


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
    return int(info["User"]), int(info.get("VTNr") or 0), sid


def locked(sid):
    out = subprocess.run(["loginctl", "show-session", sid, "-p", "LockedHint", "--value"],
                         capture_output=True, text=True).stdout.strip()
    return out == "yes"


def compositor_alive(uid):
    """Wayland-„sync“ an KWin schicken: ein hängender Compositor beantwortet ihn nicht."""
    sockets = sorted(p for p in glob.glob(f"/run/user/{uid}/wayland-*") if not p.endswith(".lock"))
    for path in sockets:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(PING_WAIT)
                s.connect(path)
                # wl_display(1).sync(new_id 2): Objekt-ID, Länge<<16 | Opcode 0, neue ID
                s.sendall(struct.pack("=III", 1, 12 << 16, 2))
                buf, deadline = b"", time.monotonic() + PING_WAIT
                while time.monotonic() < deadline:
                    chunk = s.recv(4096)
                    if not chunk:
                        return False
                    buf += chunk
                    while len(buf) >= 8:
                        obj, size_op = struct.unpack_from("=II", buf)
                        if obj == 2:  # wl_callback.done
                            return True
                        buf = buf[max(size_op >> 16, 8):]
                return False
        except (ConnectionRefusedError, FileNotFoundError):
            continue  # verwaister Socket einer früheren Sitzung
        except socket.timeout:
            return False
        except OSError:
            return True  # im Zweifel nicht eingreifen
    return True  # kein Wayland – nichts zu prüfen


def menu_open(uid):
    """Ist der Strg+Alt+Entf-Bildschirm gerade offen? (Quittung enthält dann die PID)"""
    try:
        pid = open(f"/run/user/{uid}/easylinux-sessionmenu.ack").read().strip()
    except OSError:
        return False
    return pid.isdigit() and os.path.exists(f"/proc/{pid}")


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
                    session = active_session()
                    if not session:
                        continue  # Anmeldebildschirm o. Ä.
                    uid, vt, sid = session
                    if locked(sid):
                        # Sperrbildschirm nimmt keine Tastenkürzel an – nur eingreifen, wenn KWin hängt
                        if compositor_alive(uid):
                            continue
                        log("KWin antwortet nicht (gesperrt)")
                    elif not menu_open(uid):  # erneut gedrückt bei offenem Menü → Bild hängt
                        time.sleep(ACK_WAIT)
                        if not compositor_alive(uid):
                            log("KWin antwortet nicht")
                        elif acked_since(uid, now):
                            continue  # Oberfläche hat reagiert
                    held.clear()
                    show_menu(uid, vt)
                    # Tasten, die während des Menüs gedrückt wurden, verwerfen
                    for f in fds:
                        try:
                            while os.read(f, 4096):
                                pass
                        except OSError:
                            pass


if __name__ == "__main__":
    main()
