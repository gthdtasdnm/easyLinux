# easyLinux

Erweiterung für CachyOS mit KDE Plasma 6, die Bedienung und Werkzeuge an Windows anlehnt. Kein eigenes Betriebssystem.

Status: Alpha.

## Voraussetzungen

- CachyOS mit KDE Plasma (Wayland)
- Benutzer mit Administratorrechten

## Installation

[easyLinux-Installer](https://github.com/gthdtasdnm/easyLinux/releases/latest) herunterladen, ausführen, „Jetzt installieren“, danach ab- und anmelden.
Updates kommen über den Update-Manager.

Entfernen: Installer öffnen (oder Einstellungen › System › easyLinux) → „easyLinux entfernen“.

## Funktionen

- **Taskleiste und Startmenü** im Windows-Stil auf jedem Bildschirm, wahlweise zentriert oder links. Rechtsklick auf den Startknopf oder Win+X öffnet das Schnellmenü
- **Taskmanager** (Strg+Umschalt+Esc): Prozesse mit Netzwerk und GPU je App, Leistung mit Ansicht je Prozessorkern, App-Verlauf, Autostart, Benutzer, Details, Dienste
- **Strg+Alt+Entf**: Sperren, Benutzer wechseln, Abmelden, Taskmanager, Neu starten, Herunterfahren
- **Notfall-Hilfe**: hängt die Oberfläche, öffnet ein zweites Strg+Alt+Entf ein Textmenü (App beenden, Oberfläche neu starten)
- **Speicher-Wächter**: beendet bei Speicherüberlastung die verantwortliche App, bevor das System einfriert
- **Einstellungen** in einem Fenster, Aufbau wie Windows 11, Suche mit Synonymen, eigene Seiten für Bildschirm, Netzwerk, Datum & Uhrzeit und Taskleiste. Win+I öffnet sie, KDE-Aufrufe (Rechtsklick auf Uhr, Lautstärke …) landen ebenfalls dort
- **Fotos** und **Medienplayer**: schlanke Betrachter für Bilder, Videos und Musik
- **Update-Manager**: ein Klick, Fortschritt, Sicherheitsupdates markiert, behebt Spiegelserver- und Schlüsselfehler
- **Sicherheit**: Übersicht über Virenschutz (ClamAV, optional), Firewall, Updates, Sicherungspunkte
- **Doppelklick-Installation** für .AppImage, .flatpakref, .pkg.tar.zst; Hinweis bei .deb/.rpm
- **Snap Assist**: nach dem Andocken an Hälfte oder Viertel Auswahl der übrigen Fenster für die freie Fläche, einstellbar
- **Einheitliche App-Namen**: Dateien, Terminal, Editor, Rechner …
- **Benachrichtigungen** verschwinden nach 6 Sekunden, bleiben im Verlauf

## Hinweise

- Bootloader, Kernel, Treiber und Partitionen werden nicht verändert.
- Die Taskleiste wird ersetzt. Beim Entfernen wird der Stand vor der Installation wiederhergestellt; zwischenzeitliche Änderungen daran gehen verloren.
- Der Speicher-Wächter kann speicherintensive Programme (Spiele, VMs) beenden; ungespeicherte Daten gehen verloren.
- Administratoren können Updates ohne Passwort installieren (nur lokale, aktive Sitzung).
- Die Paketquelle ist nicht signiert.
- `ctrl-alt-del.target` wird maskiert; Strg+Alt+Entf startet auf der Konsole nicht mehr neu.

## Bei Problemen

- App hängt: Strg+Umschalt+Esc → Task beenden
- Oberfläche hängt: Strg+Alt+Entf zweimal → Notfall-Hilfe
- Nach einem Update defekt: beim Start einen Snapshot im Bootmenü wählen (nur wenn Snapper und snap-pac eingerichtet sind)
- easyLinux entfernen ohne Oberfläche: Strg+Alt+F3, anmelden, `sudo pacman -R easylinux`

Fehler: [Issues](https://github.com/gthdtasdnm/easyLinux/issues)

## Technisches

pacman-Paket `easylinux` aus eigener Paketquelle:

```ini
[easylinux]
SigLevel = Optional TrustAll
Server = https://github.com/gthdtasdnm/easyLinux/releases/download/repo
```

- Programme unter `/opt/easylinux` (Python, PySide6/QML, Kirigami); C++-Teile werden auf dem Zielrechner gebaut und nach Plasma-Updates per pacman-Hook neu gebaut
- Einrichtung pro Benutzer beim Anmelden (`user/*/apply.sh`), geänderte Dateien in `~/.config` werden vorher gesichert
- Systemweit: emergency-Dienst (root, evdev), systemd-oomd, Polkit-Regeln, `.desktop`-Kopien in `/usr/local/share/applications`, Weiterleitungen `/usr/local/bin/systemsettings` und `kcmshell6`, Flatpak-Overrides, KWin-Skript
- Alles wird beim Entfernen zurückgenommen

Aus dem Quellcode: `./install.sh` / `./uninstall.sh`. Codeübersicht: [`CLAUDE.md`](CLAUDE.md), Test-VM: [`tools/vm/README.md`](tools/vm/README.md).

Lizenz: noch nicht festgelegt.
