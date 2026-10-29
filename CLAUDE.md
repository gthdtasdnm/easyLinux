# easyLinux – Hinweise für KI-Assistenten

CachyOS + KDE Plasma 6 (Wayland) einsteigerfreundlich und Windows-ähnlich machen. Alpha, benutzbar.
Sprache im Projekt: **Deutsch** (Code-Kommentare, Oberfläche, Commits). Nutzer ist kein Entwickler – Erklärungen einfach halten.

## Wo was liegt

| Pfad | Inhalt |
|---|---|
| `apps/easylinux/` | gemeinsame Python-Bausteine: `procapps` (Apps statt Prozesse über systemd-Gruppen), `desktop` (.desktop lesen), `single` (eine Instanz + Nachrichten), `services`, `sysperf`, `autostart` |
| `apps/taskmanager/` | Taskmanager (Tabs wie Win 11) **und** Strg+Alt+Entf-Bildschirm `SessionMenu.qml` (Layer-Shell, deckend, ohne Animation) – ein vorgeladener Prozess (`easylinux-taskmanager.service`) |
| `apps/emergency/` | Notfall-Dienst (root, liest Tastatur per evdev) + Textmenü auf Konsole 9, falls die Oberfläche hängt |
| `apps/settings/` | Einstellungen wie Win 11 in einem Fenster. Einträge/Suche: `settings_entries.py`. Eigene Seiten: `page:display` (`DisplayPage.qml`+`display.py`), `page:snapassist` (`SnapAssistPage.qml`+`snapassist.py`), `page:developer` (eigene Dienste: `DeveloperPage.qml`+`developer.py`, Suche in `easylinux/myservices.py`), `page:installed`. Gemeinsame Karte: `Card.qml`. `kcmhost/` = C++-Brücke, bettet KDE-KCMs ein |
| `apps/updater/`, `apps/security/` | Update-Manager bzw. Sicherheit-App; root-Teil jeweils `helper.py` über pkexec/Polkit |
| `apps/openfile/` | Doppelklick-Installation (.AppImage, .flatpakref, .pkg.tar.zst, .deb/.rpm-Hinweis) |
| `apps/taskbarmenu/` | C++-Plasma-Plugin: Rechtsklickmenü der Leiste |
| `apps/installer/` | grafischer Installer (C++/QML, eine Datei). `install-root.sh` trägt Paketquelle `[easylinux]` in `/etc/pacman.conf` ein, `remove-root.sh` entfernt alles |
| `bin/` | Startskripte; `easylinux-user-setup` (Einrichtung pro Benutzer beim Anmelden), `easylinux-names` (einheitliche App-Namen), `easylinux-rebuild` (C++-Teile nach Plasma-Updates neu bauen), `easylinux-shortcut` |
| `user/NN-name/` | Einrichtung pro Benutzer: `apply.sh` + `revert.sh`, laufen in Nummern-Reihenfolge. `user/VERSION` erhöhen → läuft beim nächsten Anmelden erneut |
| `lib/common.sh` | `backup_config` (sichert Stand **vor** erster Installation), `restore_configs` u. a. |
| `system/` | Dateien genau so, wie sie im System landen (systemd, Polkit, pacman-Hooks, KWin-Skript `usr/share/kwin/scripts/easylinux-snapassist/`) |
| `packaging/` | `PKGBUILD` + `easylinux.install` (systemweite Schritte: ctrl-alt-del.target maskieren, oomd, Flatpak-Overrides) |
| `tools/vm/` | Test-VM steuern (siehe `tools/vm/README.md`), `tools/release/release.sh` veröffentlicht auf GitHub |

Installiert liegt alles unter `/opt/easylinux` (Programme) bzw. direkt im System (`system/`).

## Arbeitsweise

- **Nur in der VM testen**, nie ungefragt auf dem Host installieren. VM: `tools/vm/login` (bootet nicht selbst – vorher `virsh -c qemu:///session start boxes-unknown-2`).
- Kleine Änderungen: `tools/vm/deploy` (spielt apps/bin/data/lib/user nach /opt/easylinux, startet Dienste neu) – **keine** Neuinstallation.
- Gast-Shell ist **fish**: Befehle über `tools/vm/vsess '…'` bzw. Skriptdatei + `bash datei`. Kein `x=y`, kein `$?`.
- `tools/vm/vm shot` liefert manchmal ein **veraltetes Bild** → vorher `tools/vm/vm click` in eine leere Ecke, oder Zustand per KWin-Skript abfragen.
- Tastendruck/Andocken deterministisch: kleines KWin-JS-Skript per `qdbus6 org.kde.KWin /Scripting …loadScript` laden, `print()` landet im User-Journal.
- Oberfläche ohne VM prüfen: QML offscreen rendern (`QT_QPA_PLATFORM=offscreen`, `QQuickWindow.grabWindow()`).
- Release: `VERSION` erhöhen, `tools/release/release.sh [Installer]` – veröffentlicht öffentlich, nur nach Rückfrage.

## Stolpersteine

- **KWin-Skripte:** QML wird bis zur Neuanmeldung gecacht, auch fehlgeschlagene Ladeversuche je Pfad → zum Testen jedes Mal in einen **neuen** `/tmp`-Ordner kopieren und per `loadDeclarativeScript` laden.
- **Timer im Hauptteil eines KWin-Skripts feuern nie** (nur in Fenstern wie `PlasmaCore.Dialog`) → Zeitstempel (`Date.now()`) statt Timer.
- KWin 6.8: `window.tile = …` ist veraltet und wirkungslos → `window.tile.unmanage(window)`. Quick-Tile-Befehle kombinieren sich mit der bestehenden Kachel (oben-links + rechts = oben) → vorher lösen.
- Snap-Assist-Optionen: kwinrc `[Script-easylinux-snapassist]` (`AllScreens`, `WhenOccupied`, `Quarters`), Skript liest per `KWin.readConfig` bei jedem Andocken; nach Schreiben `qdbus6 org.kde.KWin /KWin reconfigure`.
- Plasma bringt OOM-Meldungen und CachyOS Btrfs-Snapshots (snap-pac) selbst mit – nicht doppelt bauen.
- pkexec/Polkit „aktive Sitzung“ greift nicht für per SSH gestartete Programme → GUI per `kstart --` aus `vsess`.
- Systemweite Änderungen nur über Paket/`easylinux.install`, pro Benutzer nur über `user/*/apply.sh` mit `backup_config` – sonst nimmt die Deinstallation sie nicht zurück.

## Offen

Startmenü-Favoriten, Leiste auf weiteren Bildschirmen, eigener Medienplayer, Laufwerks-Seite, dauerhafte Benachrichtigungen,
Netzwerk je App, Andock-Layouts am Maximieren-Knopf, signierte Paketquelle, Snap Assist mit mehreren Bildschirmen auf echter Hardware testen.
