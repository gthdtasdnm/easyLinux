"""Entscheidet für die Umleitungen systemsettings/kcmshell6 (system/usr/local/bin), ob eine KDE-
Einstellungsseite im easyLinux-Fenster geöffnet wird. Ohne Qt, damit der Aufruf schnell bleibt.

    python3 route.py kcm_name   → Rückgabe 0: easyLinux zeigt die Seite, 1: KDE-Programm öffnen
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from settings_entries import ALIASES, ENTRIES  # noqa: E402

KCM_PLUGINS = "/usr/lib/qt6/plugins/plasma/kcms"
KCM_EMBED_DIRS = ("systemsettings", ".", "kinfocenter")  # wie in main.py/kcmhost.cpp


def handled(kcm):
    target = ALIASES.get(kcm, kcm)
    if target.startswith("page:"):
        return any(e[4] == target for e in ENTRIES)
    if not any(e[4] == target for e in ENTRIES):
        return False
    return os.path.exists(os.path.join(HERE, "kcmhost", "libkcmhost.so")) and \
        any(os.path.exists(f"{KCM_PLUGINS}/{d}/{target}.so") for d in KCM_EMBED_DIRS)


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else ""
    name = os.path.basename(name).removesuffix(".desktop")
    sys.exit(0 if name and handled(name) else 1)
