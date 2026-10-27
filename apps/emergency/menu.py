#!/usr/bin/env python3
"""Notfall-Menü auf der Textkonsole – funktioniert auch, wenn die grafische Oberfläche hängt.

Aufruf (durch daemon.py, als root): menu.py <uid> <vt der Sitzung>
Bedienung nur mit Pfeiltasten, Enter, Ziffern und Esc.
"""
import curses
import locale
import os
import pwd
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from easylinux import procapps  # noqa: E402

UID = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
SESSION_VT = sys.argv[2] if len(sys.argv) > 2 else ""
TITLE = "easyLinux Notfall-Hilfe"


def user_manager(*args):
    user = pwd.getpwuid(UID).pw_name
    return subprocess.run(["systemctl", f"--machine={user}@.host", "--user", *args],
                          capture_output=True, text=True)


def restart_desktop():
    """KWin und Plasma neu starten. Apps bleiben meist erhalten (Qt/Wayland verbinden sich neu)."""
    # Erst zurück zur Sitzung: Der neue KWin muss auf der aktiven Konsole starten,
    # sonst bekommt er den Bildschirm nicht.
    if SESSION_VT:
        subprocess.run(["chvt", SESSION_VT])
        time.sleep(1)
    for name in ("kwin_wayland", "plasmashell"):
        subprocess.run(["pkill", "-CONT", "-u", str(UID), "-x", name])
        subprocess.run(["pkill", "-KILL", "-u", str(UID), "-x", name])
    time.sleep(2)
    # plasmashell wird von systemd neu gestartet; zur Sicherheit anstoßen
    user_manager("start", "plasma-plasmashell.service")


def force_logout():
    sessions = subprocess.run(["loginctl", "list-sessions", "--no-legend"], capture_output=True, text=True).stdout
    for line in sessions.splitlines():
        parts = line.split()
        if len(parts) > 1 and parts[1] == str(UID):
            subprocess.run(["loginctl", "terminate-session", parts[0]])


def draw_box(scr, title, lines, options, sel, footer):
    scr.erase()
    h, w = scr.getmaxyx()
    width = min(76, w - 2)
    top, left = 1, max(0, (w - width) // 2)
    scr.attron(curses.A_BOLD)
    scr.addnstr(top, left, title.center(width), width, curses.A_REVERSE | curses.A_BOLD)
    scr.attroff(curses.A_BOLD)
    y = top + 2
    for text in lines:
        scr.addnstr(y, left + 2, text, width - 4)
        y += 1
    y += 1
    first = 0
    visible = max(1, h - y - 3)
    if sel >= visible:
        first = sel - visible + 1
    for i, opt in enumerate(options[first:first + visible], start=first):
        attr = curses.A_REVERSE if i == sel else curses.A_NORMAL
        label = f" {i + 1:>2}  {opt}" if len(options) < 10 or i < 9 else f"     {opt}"
        scr.addnstr(y, left + 2, label.ljust(width - 4), width - 4, attr)
        y += 1
    scr.addnstr(h - 2, left, footer.center(width), width, curses.A_DIM)
    scr.refresh()


def choose(scr, title, lines, options, footer="↑/↓ auswählen · Enter bestätigen · Esc zurück"):
    sel = 0
    while True:
        draw_box(scr, title, lines, options, sel, footer)
        key = scr.getch()
        if key in (curses.KEY_UP, ord("k")):
            sel = (sel - 1) % len(options)
        elif key in (curses.KEY_DOWN, ord("j")):
            sel = (sel + 1) % len(options)
        elif key in (curses.KEY_ENTER, 10, 13):
            return sel
        elif key == 27:
            return None
        elif ord("1") <= key <= ord("9") and key - ord("1") < len(options):
            return key - ord("1")


def message(scr, text):
    draw_box(scr, TITLE, text.split("\n"), ["OK"], 0, "Enter: weiter")
    while scr.getch() not in (curses.KEY_ENTER, 10, 13, 27):
        pass


def confirm(scr, question):
    return choose(scr, TITLE, [question], ["Nein, abbrechen", "Ja"]) == 1


def kill_app_menu(scr):
    monitor = procapps.Monitor(UID)
    monitor.update()
    time.sleep(1)
    apps = [a for a in monitor.update()]
    # Hängende Apps verbrauchen oft viel Rechenzeit oder Speicher → zuerst zeigen
    apps.sort(key=lambda a: (a.cpu, a.memory), reverse=True)
    if not apps:
        message(scr, "Es laufen gerade keine Apps.")
        return
    labels = [f"{a.name[:34]:<34} {a.cpu:5.1f} % CPU  {procapps.human_bytes(a.memory):>9}" for a in apps]
    sel = choose(scr, TITLE, ["Welche App soll beendet werden?",
                              "Ganz oben stehen die Apps, die gerade am meisten verbrauchen."], labels)
    if sel is None:
        return
    app = apps[sel]
    if procapps.kill_app(app):
        message(scr, f"„{app.name}“ wurde beendet.\n\nMit „Zurück zur Oberfläche“ geht es weiter.")
    else:
        message(scr, f"„{app.name}“ konnte nicht beendet werden.")


def main(scr):
    curses.curs_set(0)
    scr.keypad(True)
    curses.use_default_colors()
    options = [
        "Zurück zur Oberfläche",
        "Hängende App beenden",
        "Oberfläche neu starten (Apps bleiben meist offen)",
        "Abmelden erzwingen (alle Apps werden geschlossen)",
        "Neu starten",
        "Ausschalten",
    ]
    while True:
        sel = choose(scr, TITLE, [
            "Die Oberfläche reagiert nicht? Hier können Sie das Problem beheben,",
            "ohne den Computer auszuschalten.",
        ], options, "↑/↓ auswählen · Enter bestätigen · Esc: zurück zur Oberfläche")
        if sel in (None, 0):
            return
        if sel == 1:
            kill_app_menu(scr)
        elif sel == 2:
            restart_desktop()
            return
        elif sel == 3 and confirm(scr, "Wirklich abmelden? Ungespeicherte Änderungen gehen verloren."):
            force_logout()
            return
        elif sel == 4 and confirm(scr, "Wirklich neu starten? Ungespeicherte Änderungen gehen verloren."):
            subprocess.run(["systemctl", "reboot"])
            return
        elif sel == 5 and confirm(scr, "Wirklich ausschalten? Ungespeicherte Änderungen gehen verloren."):
            subprocess.run(["systemctl", "poweroff"])
            return


if __name__ == "__main__":
    locale.setlocale(locale.LC_ALL, "")
    os.environ.setdefault("ESCDELAY", "50")
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    curses.wrapper(main)
