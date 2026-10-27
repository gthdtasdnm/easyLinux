# easyLinux

**Linux, das sich anfühlt wie zu Hause.** easyLinux macht [CachyOS](https://cachyos.org) mit KDE Plasma
für Umsteiger von Windows einfach: vertraute Bedienung, verständliche Namen, Werkzeuge für den Notfall –
und alles lässt sich mit einem Klick wieder entfernen.

> **Alpha-Version.** easyLinux ist benutzbar und wird täglich verwendet, aber noch jung. Es kann Fehler geben.
> Bitte lies vor der Installation den Abschnitt [Bevor du installierst](#bevor-du-installierst).

**[⬇ easyLinux-Installer herunterladen](https://github.com/gthdtasdnm/easyLinux/releases/latest)**

---

## Für Einsteiger

### Was ist easyLinux?

Du hast gerade von Windows zu Linux gewechselt – oder überlegst es dir? Dann kennst du das: Vieles ist
ähnlich, aber eben nicht gleich. Die Programme heißen anders, der Taskmanager fehlt, Strg+Alt+Entf meldet
dich ab, und wenn etwas hängt, weiß man nicht weiter.

easyLinux ist **kein eigenes Betriebssystem**. Es ist eine Ergänzung für CachyOS, die die Oberfläche so
einrichtet, wie man es von Windows kennt, und die fehlenden Werkzeuge mitbringt. Dein Linux bleibt dabei
ein ganz normales CachyOS.

### Was bekomme ich?

| Von Windows kennst du … | easyLinux bringt … |
|---|---|
| Taskleiste und Startknopf | Taskleiste unten mit Startmenü und angehefteten Apps. Rechtsklick auf den Startknopf öffnet das bekannte Schnellmenü (Terminal, Taskmanager, Einstellungen, Herunterfahren …) |
| Task-Manager (**Strg+Umschalt+Esc**) | Taskmanager mit den gleichen Tabs: Prozesse, Leistung, Autostart, Details, Dienste. Zeigt Apps statt kryptischer Prozessnamen und öffnet sofort, auch wenn der Computer ausgelastet ist |
| **Strg+Alt+Entf** | Der bekannte Bildschirm: Sperren, Benutzer wechseln, Abmelden, Taskmanager, Neu starten, Herunterfahren. Hängt die Oberfläche komplett, öffnet ein zweites Strg+Alt+Entf eine Notfall-Hilfe, mit der du hängende Apps beenden oder die Oberfläche neu starten kannst – ohne den Stecker zu ziehen |
| Einstellungen | Einstellungen im Windows-11-Aufbau in einem einzigen Fenster, mit einer Suche, die versteht, was du meinst („Bildschirm“ findet auch Auflösung, Skalierung und Nachtlicht) |
| Windows Update | Update-Manager: ein Klick, Fortschrittsbalken, Restzeit. Sicherheitsupdates werden hervorgehoben, Probleme mit Paketservern löst er selbst |
| Windows-Sicherheit | Sicherheit-App mit Ampel für Virenschutz, Firewall, Updates und Sicherungspunkte. Den Virenschutz richtest du auf Wunsch mit einem Klick ein |
| Apps & Features | „Installierte Apps“ – mit einem Klick deinstallieren |
| Doppelklick auf eine Setup-Datei | Doppelklick auf heruntergeladene Programme (.AppImage, Flatpak, Pakete) installiert sie. Bei Windows-ähnlichen Linux-Formaten (.deb/.rpm) wird erklärt, wo es die App stattdessen gibt |
| Snap Assist | Fenster an den Rand ziehen (oder **Meta + Pfeiltaste**) → die anderen Fenster erscheinen zur Auswahl für die freie Fläche. Funktioniert auch mit Bildschirmvierteln und bietet Fenster von allen Bildschirmen an, einstellbar unter *Einstellungen › System › Snap Assist* |
| Verständliche App-Namen | „Dateien“, „Terminal“, „Editor“, „Medienplayer“, „Rechner“ statt Dolphin, Konsole, Kate … |
| Benachrichtigungen | Verschwinden nach einigen Sekunden und bleiben im Verlauf |
| Schutz vor Einfrieren | Wenn der Arbeitsspeicher voll läuft, wird die verantwortliche App beendet, bevor der ganze Computer einfriert – mit Meldung, welche es war |

### Was brauche ich?

- **CachyOS mit KDE Plasma** (die Standard-Desktop-Variante). Andere Linux-Systeme werden nicht unterstützt.
- Ein Benutzerkonto mit Administratorrechten (das ist das Konto, das du bei der Installation von CachyOS angelegt hast).
- Internetverbindung.

### Installieren

1. **[easyLinux-Installer herunterladen](https://github.com/gthdtasdnm/easyLinux/releases/latest)** (Datei `easyLinux-Installer`).
2. Im Ordner *Downloads* doppelt darauf klicken und **Ausführen** wählen.
3. **Jetzt installieren** klicken und einmal dein Passwort eingeben.
4. Einmal **ab- und wieder anmelden** – fertig.

Updates für easyLinux kommen danach automatisch über den Update-Manager, zusammen mit allen anderen Updates.

### Wieder entfernen

Installer erneut öffnen (oder *Einstellungen › System › easyLinux*) → **easyLinux entfernen**. Danach einmal
ab- und anmelden. Deine Taskleiste und die geänderten Einstellungen werden auf den Stand von vor der
Installation zurückgesetzt. Apps, die du in der Zwischenzeit installiert hast, bleiben erhalten.

### Bevor du installierst

easyLinux ist eine **Alpha-Version**. Damit du weißt, worauf du dich einlässt:

**Kann easyLinux meinen Computer kaputt machen?**
Sehr unwahrscheinlich. easyLinux verändert **nichts** am Startvorgang, am Linux-Kern, an Treibern, Festplatten
oder Partitionen und löscht keine eigenen Dateien. Es richtet hauptsächlich die Oberfläche ein und bringt
eigene Programme mit. Das Schlimmste, was realistisch passieren kann: Die Oberfläche verhält sich nach einem
Fehler seltsam (z. B. fehlt die Taskleiste). Das lässt sich immer beheben – siehe [Wenn etwas schiefgeht](#wenn-etwas-schiefgeht).

**Das solltest du wissen:**

- ⚠️ **Deine Taskleiste wird ersetzt.** Hast du Taskleiste oder Startmenü schon selbst angepasst, ist das nach
  der Installation durch die easyLinux-Leiste ersetzt. Beim Entfernen kommt dein alter Stand zurück –
  Änderungen, die du *zwischendurch* an der Leiste gemacht hast, gehen dabei aber verloren.
- ⚠️ **Der Speicher-Wächter beendet Apps.** Ist der Arbeitsspeicher länger als etwa 10 Sekunden überlastet,
  wird die App beendet, die ihn am stärksten beansprucht. Das schützt vor einem eingefrorenen Computer, kann aber auch
  große Spiele, virtuelle Maschinen oder Bildbearbeitung mit sehr großen Dateien treffen. Ungespeicherte
  Arbeit in dieser App ist dann verloren – also regelmäßig speichern.
- ⚠️ **Updates ohne Passwort.** Administratoren können Updates im Update-Manager ohne Passwort installieren
  (nur diese eine Aktion und nur, wenn man selbst am Computer sitzt). Das ist bequem, bedeutet aber auch:
  Wer an deinem entsperrten Computer sitzt, kann Updates starten. Sperre den Bildschirm, wenn du weggehst
  (**Meta + L** oder Strg+Alt+Entf → Sperren).
- ⚠️ **System-Updates sind immer vollständig.** Wie bei jedem Arch-basierten System kann ein Update selten
  Probleme machen. CachyOS legt vor jedem Update automatisch einen **Sicherungspunkt** an, zu dem du
  zurückkehren kannst (wenn CachyOS mit dem Standard-Dateisystem Btrfs installiert wurde).
- ⚠️ **Die Paketquelle ist (noch) nicht signiert.** easyLinux und seine Updates kommen direkt aus diesem
  GitHub-Projekt. Du vertraust damit diesem Projekt – genau wie bei jeder anderen Software aus dem Internet.
- ℹ️ **Strg+Alt+Entf startet nicht mehr sofort neu.** Das war unter Linux bisher die Standardeinstellung auf
  der Textkonsole. Dafür gibt es jetzt den Windows-Bildschirm und die Notfall-Hilfe. Der dazugehörige Dienst
  liest die Tastatur, achtet aber ausschließlich auf diese eine Tastenkombination und speichert nichts.

**Tipp:** Lege vor der Installation selbst einen Sicherungspunkt an: *Einstellungen › Update › Sicherungspunkte*
(Btrfs Assistant) → *Snapper* → *Neu*.

### Wenn etwas schiefgeht

1. **Eine App hängt:** Strg+Umschalt+Esc → Taskmanager → App auswählen → *Task beenden*.
2. **Die ganze Oberfläche hängt:** Strg+Alt+Entf, und wenn nichts passiert, noch einmal Strg+Alt+Entf →
   Notfall-Hilfe → *Oberfläche neu starten*.
3. **Nach einem Update startet etwas nicht mehr richtig:** Computer neu starten und im Startmenü (Bootloader)
   einen **Snapshot** von vor dem Update auswählen. Danach in *Sicherungspunkte* dauerhaft wiederherstellen.
4. **easyLinux selbst macht Probleme und der Installer geht nicht auf:** Mit **Strg+Alt+F3** auf eine
   Textkonsole wechseln, anmelden und eingeben:
   ```
   sudo pacman -R easylinux
   ```
   Danach neu starten. Mit **Strg+Alt+F1** (oder F2) kommst du zurück zur Oberfläche.

Fehler bitte als [Issue](https://github.com/gthdtasdnm/easyLinux/issues) melden – am besten mit einer kurzen
Beschreibung, was du gemacht hast und was passiert ist.

### Was noch fehlt

- Die Taskleiste erscheint nur auf dem Hauptbildschirm.
- Einige ältere KDE-Einstellungsseiten öffnen sich noch in einem eigenen Fenster.
- Eigener Medienplayer (bis dahin: Haruna als „Medienplayer“), Laufwerks-Seite in den Einstellungen,
  Andock-Layouts am Maximieren-Knopf wie bei Windows 11.

---

## Für Fortgeschrittene

### Aufbau

easyLinux ist ein normales pacman-Paket (`easylinux`, arch=any) aus einer eigenen Paketquelle:

```ini
[easylinux]
SigLevel = Optional TrustAll
Server = https://github.com/gthdtasdnm/easyLinux/releases/download/repo
```

Der Installer (C++/QML, eine Datei) trägt die Quelle in `/etc/pacman.conf` ein, installiert das Paket per
pkexec und richtet den Benutzer ein. Beim Entfernen nimmt er beides zurück.

- **Programme** liegen unter `/opt/easylinux` – Python 3 + PySide6/QML mit Kirigami, damit sie zu Plasma passen.
  Zwei kleine C++-Teile (Plasma-Plugin fürs Rechtsklickmenü, `kcmhost` zum Einbetten von KDE-Einstellungsseiten)
  werden auf dem Zielrechner gegen die installierte Qt-/Plasma-Version gebaut und nach Plasma-Updates per
  pacman-Hook neu gebaut (`easylinux-rebuild`). Schlägt das fehl, fallen die Funktionen auf Plasma-Standard zurück.
- **Pro Benutzer** richtet `easylinux-user-setup` beim Anmelden Leiste, Tastenkürzel, Standard-Apps usw. ein
  (`user/NN-name/apply.sh`). Jede geänderte Datei in `~/.config` wird vorher gesichert
  (`~/.local/share/easylinux/backup/`), `revert.sh` und die Wiederherstellung nehmen alles zurück.

### Was systemweit geändert wird

| Änderung | Zweck |
|---|---|
| `[easylinux]` in `/etc/pacman.conf` | Paketquelle (unsigniert, siehe oben) |
| `ctrl-alt-del.target` maskiert | Strg+Alt+Entf auf der Konsole startet nicht neu |
| `easylinux-emergency.service` (root) | liest Tastaturen per evdev, prüft per Wayland-Ping, ob KWin antwortet; sonst Textmenü auf VT 9 |
| `systemd-oomd` aktiviert + `user-.slice.d`/`oomd.conf.d` | Speicher-Wächter (Speicherdruck über 50 % für 10 s → kill) |
| Polkit-Regeln `org.easylinux.update`, `org.easylinux.security` | Gruppe `wheel`, nur aktive lokale Sitzung, ohne Passwort |
| `/usr/local/share/applications/*.desktop` | angepasste Kopien für einheitliche Namen (pacman-Hook hält sie aktuell) |
| `/var/lib/flatpak/overrides/global` (nur falls nicht vorhanden) | Flatpak-Apps übernehmen Farben und Schrift |
| Flathub-Remote | wird hinzugefügt, falls er fehlt |
| KWin-Skript `easylinux-snapassist`, Benutzerdienste für Taskmanager und Update-Prüfung | |

Alles davon wird beim Entfernen zurückgenommen (`packaging/easylinux.install`, `apps/installer/remove-root.sh`).
Von der Sicherheit-App nachinstallierte Pakete (z. B. ClamAV) werden protokolliert und mit entfernt.

### Aus dem Quellcode

```bash
git clone https://github.com/gthdtasdnm/easyLinux && cd easyLinux
./install.sh     # Paket bauen (makepkg), installieren, Benutzer einrichten
./uninstall.sh   # alles wieder entfernen
```

Den Installer baut `apps/installer/build.sh`, veröffentlicht wird mit `tools/release/release.sh`.

### Entwicklung

Entwickelt und getestet wird in einer frischen CachyOS-VM (GNOME Boxes), die sich vom Host aus fernsteuern
lässt – siehe [`tools/vm/README.md`](tools/vm/README.md). Eine Übersicht über den Code, Arbeitsweise und
bekannte Stolpersteine steht in [`CLAUDE.md`](CLAUDE.md).

Grundsätze: Einsteiger zuerst (kein Terminal nötig), einheitliche Namen und ein Design, Notfall-Werkzeuge
müssen *immer* funktionieren, und alles muss rückgängig zu machen sein.

### Lizenz

Noch nicht festgelegt.
