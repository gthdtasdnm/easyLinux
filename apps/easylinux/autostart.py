"""Autostart-Apps (XDG-Autostart) anzeigen und ein-/ausschalten – wie der Autostart-Tab von Windows.

Ausschalten ändert nie die Originaldatei: für Einträge aus /etc/xdg/autostart wird eine Kopie mit
Hidden=true in ~/.config/autostart angelegt (so sieht es der XDG-Standard vor), eigene Einträge
bekommen Hidden=true. Einschalten macht genau das wieder rückgängig.
"""
import os

from . import desktop

USER_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "autostart")
SYSTEM_DIRS = [os.path.join(d, "autostart")
               for d in os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg").split(":") if d]
MARK = "X-EasyLinux-Disabled"

# Ohne diese Teile funktioniert die Oberfläche nicht richtig – nicht zum Abschalten anbieten.
ESSENTIAL = {"at-spi-dbus-bus", "gmenudbusmenuproxy", "kaccess", "org.kde.plasma-fallback-session-restore",
             "org.kde.plasmashell", "pam_kwallet_init", "polkit-kde-authentication-agent-1", "powerdevil",
             "spice-vdagent", "xdg-user-dirs", "xdg-user-dirs-kde", "xembedsniproxy", "geoclue-demo-agent",
             "org.kde.discover.notifier", "kde-systemd-start-condition", "easylinux-update-check"}

# Verständlichere Namen für bekannte Hintergrundprogramme
NAMES = {"baloo_file": ("Dateisuche (Indizierung)", "Durchsucht Ihre Dateien, damit die Suche schnell ist"),
         "org.kde.kdeconnect.daemon": ("KDE Connect", "Verbindet Ihr Handy mit dem Computer"),
         "arch-update-tray": ("Arch-Update-Hinweis", "Zweiter Update-Hinweis (easyLinux hat einen eigenen)"),
         "cachyos-hello": ("CachyOS Willkommen", "Begrüßungsfenster beim Anmelden"),
         "limine-snapper-notify": ("Sicherungspunkt-Hinweis", "Meldet, wenn von einem Sicherungspunkt gestartet wurde"),
         "limine-restore-notify": ("Wiederherstellungs-Hinweis", "Meldet eine Wiederherstellung von Sicherungspunkten")}


def _shown_in_kde(f):
    only = [x for x in f.get("OnlyShowIn", "").split(";") if x]
    not_in = [x for x in f.get("NotShowIn", "").split(";") if x]
    return (not only or "KDE" in only) and "KDE" not in not_in


def _write(path, fields):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\n")
        for k, v in fields.items():
            fh.write(f"{k}={v}\n")


def _set_key(path, key, value):
    """Einen Schlüssel in [Desktop Entry] setzen und den Rest der Datei unverändert lassen."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    out, section, done = [], None, False
    for line in lines:
        s = line.strip()
        if s.startswith("["):
            if section == "[Desktop Entry]" and not done:
                out.append(f"{key}={value}")
                done = True
            section = s
        elif section == "[Desktop Entry]" and s.split("=", 1)[0].strip() == key:
            if not done:
                out.append(f"{key}={value}")
                done = True
            continue
        out.append(line)
    if not done:
        out.append(f"{key}={value}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


def entries():
    found = {}
    for base in reversed(SYSTEM_DIRS):
        for fn in sorted(os.listdir(base)) if os.path.isdir(base) else []:
            if fn.endswith(".desktop"):
                found[fn] = {"system": os.path.join(base, fn), "user": None}
    if os.path.isdir(USER_DIR):
        for fn in sorted(os.listdir(USER_DIR)):
            if fn.endswith(".desktop"):
                found.setdefault(fn, {"system": None, "user": None})["user"] = os.path.join(USER_DIR, fn)
    result = []
    for fn, src in found.items():
        did = fn[:-8]
        if did in ESSENTIAL or did.startswith("easylinux-"):
            continue
        sys_f = desktop.parse(src["system"]) if src["system"] else {}
        user_f = desktop.parse(src["user"]) if src["user"] else {}
        f = dict(sys_f, **user_f)
        if f.get("Type", "Application") != "Application" or not _shown_in_kde(f):
            continue
        if sys_f and sys_f.get("Hidden") == "true":
            continue  # vom System selbst abgeschaltet
        entry = desktop.Entry(src["user"] or src["system"], did, f)
        name, comment = NAMES.get(did, (entry.name, entry.get("Comment", "")))
        app = desktop.find(did)
        icon = f.get("Icon") or (app.icon if app else "application-x-executable")
        result.append({"id": did, "name": name, "comment": comment, "icon": icon,
                       "enabled": f.get("Hidden") != "true" and f.get("X-GNOME-Autostart-enabled") != "false",
                       "system": bool(src["system"])})
    return sorted(result, key=lambda e: e["name"].lower())


def set_enabled(did, on):
    fn = did + ".desktop"
    user = os.path.join(USER_DIR, fn)
    system = next((os.path.join(d, fn) for d in SYSTEM_DIRS if os.path.exists(os.path.join(d, fn))), None)
    if on:
        if os.path.exists(user):
            f = desktop.parse(user)
            if f.get(MARK) == "true" and system:
                os.remove(user)  # unsere Abschalt-Kopie – Original gilt wieder
            else:
                _set_key(user, "Hidden", "false")
                if f.get("X-GNOME-Autostart-enabled") == "false":
                    _set_key(user, "X-GNOME-Autostart-enabled", "true")
    else:
        if os.path.exists(user):
            _set_key(user, "Hidden", "true")
        elif system:
            f = desktop.parse(system)
            keep = ("Type", "Exec", "Icon", "Name", "Name[de]", "Name[de_DE]", "Comment", "Comment[de]")
            _write(user, {k: v for k, v in f.items() if k in keep} | {"Hidden": "true", MARK: "true"})
