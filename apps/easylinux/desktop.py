"""Desktop-Einträge (.desktop-Dateien) finden und lesen – mit deutschen Namen."""
import os
import shlex
from functools import lru_cache

LANGS = ("de_DE", "de")


def data_dirs():
    home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    extra = [os.path.expanduser("~/.local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    return [home] + extra + dirs


class Entry:
    def __init__(self, path, desktop_id, fields):
        self.path = path
        self.id = desktop_id
        self.f = fields

    def get(self, key, default=""):
        for lang in LANGS:
            if f"{key}[{lang}]" in self.f:
                return self.f[f"{key}[{lang}]"]
        return self.f.get(key, default)

    @property
    def name(self):
        return self.get("Name", self.id)

    @property
    def icon(self):
        return self.f.get("Icon", "application-x-executable")

    @property
    def hidden(self):
        return self.f.get("NoDisplay") == "true" or self.f.get("Hidden") == "true"

    @property
    def binary(self):
        try:
            argv = shlex.split(self.f.get("Exec", ""))
        except ValueError:
            return ""
        # "env FOO=1 prog" und "flatpak run …" überspringen
        while argv and (argv[0] == "env" or "=" in argv[0]):
            argv.pop(0)
        return os.path.basename(argv[0]) if argv else ""


def parse(path):
    fields, section = {}, None
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("["):
                    section = line
                elif section == "[Desktop Entry]" and "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    fields[k.strip()] = v.strip()
    except OSError:
        pass
    return fields


@lru_cache(maxsize=1)
def all_entries():
    """Alle Einträge, der erste Fund pro ID gewinnt (Benutzer vor System)."""
    found = {}
    for base in data_dirs():
        root = os.path.join(base, "applications")
        for dirpath, _, files in os.walk(root):
            for fn in files:
                if not fn.endswith(".desktop"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                did = rel[:-8].replace(os.sep, "-")
                if did not in found:
                    found[did] = Entry(os.path.join(dirpath, fn), did, parse(os.path.join(dirpath, fn)))
    return found


def find(app_id):
    """Eintrag zu einer Desktop-ID oder einem Programmnamen suchen."""
    entries = all_entries()
    if not app_id:
        return None
    if app_id in entries:
        return entries[app_id]
    low = app_id.lower()
    for e in entries.values():
        if e.id.lower() == low or e.id.lower().endswith("." + low):
            return e
    for e in entries.values():
        if not e.hidden and e.binary == app_id:
            return e
    for e in entries.values():
        if e.f.get("StartupWMClass", "").lower() == low:
            return e
    return None
