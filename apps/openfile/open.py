#!/usr/bin/env python3
"""Doppelklick auf eine heruntergeladene Programmdatei → installieren, wie bei Windows.

  .AppImage      → nach ~/Programme, ausführbar machen, ins Startmenü eintragen, starten
  .flatpakref    → mit Flatpak installieren
  .pkg.tar.zst   → nach Rückfrage mit pacman installieren
  .deb / .rpm    → erklären, warum das nicht passt, und dieselbe App aus den Paketquellen
                   oder von Flathub anbieten
Ist der Virenschutz (Sicherheit-App) eingerichtet, wird die Datei vorher mit ClamAV geprüft.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
APPDIR = os.path.join(HOME, "Programme")
DESKTOP_DIR = os.path.join(HOME, ".local/share/applications")
ICON_DIR = os.path.join(HOME, ".local/share/icons/easylinux-appimage")
TITLE = "Programm installieren"


def kd(*args):
    return subprocess.run(["kdialog", "--title", TITLE, *args], capture_output=True, text=True)


def info(text):
    kd("--msgbox", text)


def ask(text, yes="Installieren", no="Abbrechen"):
    return kd("--yes-label", yes, "--no-label", no, "--yesno", text).returncode == 0


def error(text):
    kd("--error", text)


def notify(title, text, icon="dialog-information"):
    subprocess.run(["notify-send", "-a", TITLE, "-i", icon, title, text], check=False)


def run_with_progress(cmd, text):
    """Befehl ausführen und währenddessen einen Fortschrittsdialog zeigen."""
    ref = kd("--progressbar", text, "0").stdout.split()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if len(ref) == 2:
        subprocess.run(["qdbus6", ref[0], ref[1], "org.kde.kdialog.ProgressDialog.close"], capture_output=True)
    return proc


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "app"


# ---------------------------------------------------------------- Virenprüfung

def virus_free(path):
    """Datei mit ClamAV prüfen, falls der Virenschutz eingerichtet ist. False = Bedrohung gefunden."""
    if not shutil.which("clamscan") or not glob.glob("/var/lib/clamav/daily.c[lv]d"):
        return True
    r = run_with_progress(["clamscan", "--no-summary", "--stdout", path],
                          f"„{os.path.basename(path)}“ wird auf Viren geprüft …")
    if r.returncode != 1:
        return True  # sauber – oder Prüfung nicht möglich: dann nicht blockieren
    threat = r.stdout.strip().rpartition(": ")[2].removesuffix(" FOUND")
    if kd("--warningyesno", f"Achtung: In „{os.path.basename(path)}“ wurde Schadsoftware gefunden ({threat}).\n\n"
          "Die Installation wurde abgebrochen. Soll die Datei gelöscht werden?",
          "--yes-label", "Löschen", "--no-label", "Behalten").returncode == 0:
        os.remove(path)
        notify("Datei gelöscht", f"„{os.path.basename(path)}“ wurde entfernt.", "security-high")
    return False


# ---------------------------------------------------------------- AppImage

def extract(appimage, pattern, tmp):
    """Dateien aus der AppImage auspacken; Verweise (Symlinks) werden mit ausgepackt."""
    root = os.path.join(tmp, "squashfs-root")
    subprocess.run([appimage, "--appimage-extract", pattern], cwd=tmp, capture_output=True, timeout=60)
    found = glob.glob(os.path.join(root, pattern))
    result = []
    for path in found:
        cur = path
        for _ in range(6):  # Verweiskette entlanggehen und fehlende Ziele nachladen
            if not os.path.islink(cur):
                break
            nxt = os.path.normpath(os.path.join(os.path.dirname(cur), os.readlink(cur)))
            if not os.path.lexists(nxt):
                subprocess.run([appimage, "--appimage-extract", os.path.relpath(nxt, root)],
                               cwd=tmp, capture_output=True, timeout=60)
            cur = nxt
        if os.path.exists(path):
            result.append(os.path.realpath(path))
    return result


def install_appimage(path):
    os.makedirs(APPDIR, exist_ok=True)
    target = os.path.join(APPDIR, os.path.basename(path))
    if os.path.abspath(path) != os.path.abspath(target):
        shutil.move(path, target)
    os.chmod(target, 0o755)

    name, icon, categories = re.sub(r"[-_.]?(x86_64|amd64|linux|\d[\d.]*).*\.AppImage$", "",
                                    os.path.basename(target), flags=re.I) or "App", "application-x-executable", ""
    with tempfile.TemporaryDirectory() as tmp:
        desk = extract(target, "*.desktop", tmp)
        if desk:
            section = ""
            for line in open(desk[0], errors="replace"):
                line = line.strip()
                if line.startswith("["):
                    section = line
                elif section == "[Desktop Entry]" and line.startswith("Name="):
                    name = line[5:]
                elif section == "[Desktop Entry]" and line.startswith("Categories="):
                    categories = line[11:]
        dir_icon = extract(target, ".DirIcon", tmp)
        if dir_icon:
            os.makedirs(ICON_DIR, exist_ok=True)
            ext = ".svg" if dir_icon[0].endswith(".svg") else ".png"
            icon = os.path.join(ICON_DIR, slug(name) + ext)
            shutil.copy(dir_icon[0], icon)

    os.makedirs(DESKTOP_DIR, exist_ok=True)
    entry = os.path.join(DESKTOP_DIR, f"appimage-{slug(name)}.desktop")
    with open(entry, "w") as fh:
        fh.write("[Desktop Entry]\nType=Application\n"
                 f"Name={name}\nExec=\"{target}\" %U\nTryExec={target}\nIcon={icon}\n"
                 f"Categories={categories or 'Utility;'}\n"
                 f"Comment=AppImage – installiert in {APPDIR}\n"
                 f"X-EasyLinux-AppImage={target}\n")
    subprocess.run(["kbuildsycoca6"], capture_output=True)
    notify(f"„{name}“ wurde installiert", "Sie finden es ab jetzt im Startmenü.", icon)
    subprocess.Popen([target], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------- Flatpak

def install_flatpakref(path):
    if not shutil.which("flatpak"):
        return error("Flatpak ist nicht installiert. Bitte easyLinux erneut installieren.")
    name = os.path.basename(path).rsplit(".", 1)[0]
    for line in open(path, errors="replace"):
        if line.startswith("Title="):
            name = line[6:].strip()
    if not ask(f"„{name}“ von Flathub installieren?"):
        return
    r = run_with_progress(["flatpak", "install", "--user", "-y", "--noninteractive", "--from", path],
                          f"„{name}“ wird installiert …")
    if r.returncode == 0:
        notify(f"„{name}“ wurde installiert", "Sie finden es ab jetzt im Startmenü.", "flatpak-discover")
    else:
        error(f"„{name}“ konnte nicht installiert werden.\n\n{r.stderr.strip()[-600:]}")


# ---------------------------------------------------------------- Arch-Paket

def install_pkg(path):
    q = subprocess.run(["pacman", "-Qip", path], capture_output=True, text=True, env=dict(os.environ, LANG="C"))
    meta = dict(re.findall(r"^(Name|Version|Description)\s*:\s*(.*)$", q.stdout, re.M))
    name = meta.get("Name", os.path.basename(path))
    text = (f"„{name}“ {meta.get('Version', '')} installieren?\n\n{meta.get('Description', '')}\n\n"
            "Hinweis: Diese Datei stammt nicht aus den offiziellen Paketquellen. "
            "Installieren Sie nur Programme aus Quellen, denen Sie vertrauen.")
    if not ask(text):
        return
    r = run_with_progress(["pkexec", "pacman", "-U", "--noconfirm", path], f"„{name}“ wird installiert …")
    if r.returncode == 0:
        notify(f"„{name}“ wurde installiert", "Sie finden es ab jetzt im Startmenü.")
    elif r.returncode not in (126, 127):
        error(f"„{name}“ konnte nicht installiert werden.\n\n{(r.stdout + r.stderr).strip()[-600:]}")


# ---------------------------------------------------------------- .deb / .rpm

def guess_name(path):
    base = os.path.basename(path)
    base = re.split(r"[_]", base)[0]                                  # name_1.2_amd64.deb
    base = re.sub(r"-\d.*$", "", base)                                # name-1.2-1.x86_64.rpm
    return base.lower()


def offer_alternative(path):
    kind = "Debian/Ubuntu" if path.endswith(".deb") else "Fedora/openSUSE"
    name = guess_name(path)
    candidates = []
    repo = subprocess.run(["pacman", "-Ss", f"^{re.escape(name)}$"], capture_output=True, text=True).stdout
    if repo:
        candidates.append(("pacman", name, f"{name} aus den Paketquellen (empfohlen)"))
    if shutil.which("flatpak"):
        out = subprocess.run(["flatpak", "search", "--columns=application,name", name],
                             capture_output=True, text=True).stdout
        for line in out.splitlines()[:3]:
            parts = line.split("\t")
            if len(parts) >= 2 and "." in parts[0]:
                candidates.append(("flatpak", parts[0], f"{parts[1]} von Flathub ({parts[0]})"))
    intro = (f"Diese Datei ist für {kind} gedacht und passt nicht zu Ihrem System.\n"
             "Die meisten Programme gibt es aber auch passend für Ihr System.")
    if not candidates:
        return info(intro + f"\n\nFür „{name}“ wurde leider nichts Passendes gefunden. "
                    "Suchen Sie auf flathub.org oder fragen Sie den Hersteller nach einer AppImage-Datei.")
    args = ["--radiolist", intro + "\n\nStattdessen installieren:"]
    for i, (_, _, label) in enumerate(candidates):
        args += [str(i), label, "on" if i == 0 else "off"]
    r = kd("--ok-label", "Installieren", "--cancel-label", "Abbrechen", *args)
    if r.returncode != 0 or not r.stdout.strip():
        return
    source, ident, label = candidates[int(r.stdout.strip())]
    if source == "pacman":
        res = run_with_progress(["pkexec", "pacman", "-S", "--needed", "--noconfirm", ident], f"{label} wird installiert …")
    else:
        res = run_with_progress(["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", ident],
                                f"{label} wird installiert …")
    if res.returncode == 0:
        notify("Installiert", f"{label.split(' (')[0]} ist jetzt im Startmenü.")
    elif res.returncode not in (126, 127):
        error("Die Installation hat nicht geklappt.\n\n" + (res.stdout + res.stderr).strip()[-600:])


def main():
    if len(sys.argv) < 2:
        return info("Bitte eine Programmdatei (z. B. .AppImage) doppelt anklicken.")
    path = os.path.abspath(sys.argv[1])
    low = path.lower()
    try:
        if low.endswith((".appimage", ".pkg.tar.zst", ".pkg.tar.xz", ".pkg.tar.gz", ".pkg.tar")) and not virus_free(path):
            return
        if low.endswith(".appimage"):
            install_appimage(path)
        elif low.endswith(".flatpakref"):
            install_flatpakref(path)
        elif re.search(r"\.pkg\.tar(\.(zst|xz|gz))?$", low):
            install_pkg(path)
        elif low.endswith((".deb", ".rpm")):
            offer_alternative(path)
        else:
            info("Dieser Dateityp wird nicht unterstützt.")
    except Exception as exc:  # Einsteiger sollen nie einen Python-Fehler sehen
        error(f"Etwas ist schiefgelaufen:\n{exc}")


if __name__ == "__main__":
    main()
