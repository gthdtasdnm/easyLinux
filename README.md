# easyLinux

Ziel: Den Einstieg in Linux – zuerst **CachyOS mit KDE Plasma 6 (Wayland)** – so einfach machen wie möglich.
Modernes, einheitliches Design, verständliche Namen, Struktur und Bedienung angelehnt an Windows
(kein 1:1-Klon von Windows 10 oder 11, sondern etwas Eigenes dazwischen, moderner).

Alles soll als Repo veröffentlicht werden, das andere herunterladen und bei sich installieren können
(erst `install.sh` + `uninstall.sh` mit Sicherung der alten Einstellungen, später Arch-Pakete / AUR).

> Status: **Grundgerüst steht und ist in der VM getestet** – Installer/Deinstaller, Taskleiste & Startmenü, Benachrichtigungen.

## Installieren / Entfernen

```bash
./install.sh     # richtet easyLinux ein, sichert vorher die alten Einstellungen
./uninstall.sh   # stellt den Zustand von vor der Installation wieder her
```

Gesichert wird nach `~/.local/share/easylinux/backup/` – immer der Stand **vor** der ersten Installation.

## Aufbau

```
install.sh / uninstall.sh   Einstieg, ohne Rückfragen
lib/common.sh               Sichern, Wiederherstellen, Plasma steuern
modules/NN-name/apply.sh    ein Modul pro Funktion, laufen in Nummern-Reihenfolge
  10-layout/                Taskleiste & Startmenü (layout.js = Plasma-Skript)
  20-notifications/         Popups verschwinden nach 6 s, Verlauf bleibt
tools/vm/                   Test-VM vom Host aus steuern (SSH, Screenshots, Tastatur, Maus)
```

Jedes Modul ruft vor einer Änderung `backup_config <datei>` auf – so bleibt alles rückgängig machbar.

---

## Grundprinzipien

- **Einsteiger zuerst:** Kein Terminal, keine `ja/nein`-Abfragen, keine Befehle, die man googeln muss.
- **Einheitlich:** Ein Design für alles, Apps heißen so, wie das, was sie tun („Medienplayer“, „Dateien“, „Taskmanager“).
- **Zuverlässig:** Lieber weniger Funktionen, die immer funktionieren, besonders bei Notfall-Werkzeugen.
- **Rückgängig machbar:** Alles, was easyLinux ändert, kann wieder entfernt werden.
- **Von 0 testen:** Entwicklung und Tests in einer frischen CachyOS-VM (GNOME Boxes), nicht nur auf dem eigenen, bereits angepassten System.

---

## Funktionen

### 1. Startmenü & Taskleiste
- Das aktuelle Layout des Autors ist zu ~90 % richtig → als **Ausgangspunkt** auslesen und als Layout-Skript speichern, das auf einem frischen System automatisch genau so eingerichtet wird.
- Moderner: abgerundete / schwebende Leiste, Unschärfe, aufgeräumtes Startmenü mit angehefteten Apps.
- Ausgelesen (Okt. 2026): Plasma-Standardleiste unten, 46 px, nicht schwebend – Startmenü, Arbeitsflächen, Taskleiste, Systemabschnitt, Uhr, „Desktop anzeigen“; Ein/Aus im Startmenü: Energie sparen, Ruhezustand, Neu starten, Herunterfahren.
- easyLinux-Version (`modules/10-layout`): gleiche Leiste, aber **schwebend**; angeheftet: Einstellungen, Dateien, Browser, Systemmonitor (statt persönlicher Apps).
- Offen: mehrere Bildschirme (das Skript legt aktuell nur eine Leiste auf dem Hauptbildschirm an).
- Aufwand: 🟢 gering

### 2. Taskmanager
- *Das* Werkzeug, wenn etwas nicht funktioniert → muss **immer** zuverlässig aufgehen.
- Hohe Priorität, sehr wenig Verbrauch, läuft im Hintergrund vorgeladen → öffnet sofort, auch unter Last.
- Lesbar: **Apps statt Prozesse** („Firefox“ statt `firefox-bin`), großer „Task beenden“-Knopf, einfache Diagramme, verständliche Begriffe.
- Tastenkürzel **Strg+Shift+Esc**.
- Aufwand: 🟠 hoch (eigenes Programm)

### 3. Strg+Alt+Entf – Notausgang
Ziel: Statt Stecker ziehen bekommt man **immer eine Reaktion**.
1. **Vorbeugen:** Speicher-Wächter beendet das Programm, das den RAM vollmacht, *bevor* das System einfriert – mit Meldung, welches Programm es war.
2. **Normalfall:** Strg+Alt+Entf → Bildschirm wie bei Windows: Taskmanager, Sperren, Benutzer wechseln, Abmelden, Neustart, Ausschalten.
3. **Oberfläche hängt:** Eigener kleiner Notfall-Dienst liest die Tastatur direkt (unabhängig von der Oberfläche). Bei Strg+Alt+Entf erscheint ein einfacher Notfall-Bildschirm: „Hängendes Programm beenden“, „Oberfläche neu starten“, „Neu starten“, „Ausschalten“.
- Grenze: Friert der Linux-Kern selbst ein, hilft nichts mehr (selten).
- Aufwand: 🟠 hoch, gründlich in der VM testen (Hänger absichtlich auslösen).

### 4. Einheitliche Apps & Namen – „DER Medienplayer“
- Alle Apps heißen, was sie tun: Medienplayer, Dateien, Bilder, Rechner, Texteditor, Taskmanager … (🟢 einfach)
- Nur Apps, die zum KDE-/Qt-Design passen (GTK-Apps wie Celluloid wirken fremd).
- **Eigener Medienplayer** auf Basis von mpv mit moderner Oberfläche im Gesamtdesign. (🟡–🟠)

### 5. Design
- Kein Theme-Programm, keine große Auswahl nötig – **ein einheitliches Design für alles**.
- Optional: Akzentfarbe / Farben anpassbar (KDE kann das bereits, auch passend zum Hintergrundbild).
- Hauptarbeit: Auch Fremd-Apps (GTK, Flatpak) sollen gleich aussehen.
- Aufwand: 🟢–🟡

### 6. Update-Manager
- Kein Terminal, keine `ja`-Abfragen, höchstens einmal ein Passwort (für Admins evtl. gar keins).
- **Ein Klick** → Fortschrittsbalken + geschätzte Restzeit.
- Zwei Bereiche:
  - **System** – wird immer komplett aktualisiert (Teil-Updates sind auf Arch/CachyOS gefährlich); wichtige Sicherheits-Updates werden hervorgehoben.
  - **Apps** (Flatpak) – auch einzeln möglich.
- Vor jedem Update automatischer Snapshot zum Zurückspringen.
- Sanfte Erinnerungen (kein Zwang), damit Updates sich nicht monatelang stauen. Hinweis „Neustart nötig“ bei Kernel-Updates.
- Bekanntes Problem (selbst erlebt): veraltete Paketliste → 404-Fehler. Der Updater muss so etwas selbst lösen.
- Aufwand: 🟠 hoch

### 7. Einstellungen
- Eigene App mit **Windows-Struktur**: System, Bluetooth & Geräte, Netzwerk, Personalisierung, Apps, Konten, Zeit & Sprache, Update.
- **Gute deutsche Suche** mit Synonymen: „Bildschirm“ → Auflösung, Skalierung, Helligkeit, Nachtlicht (heute kommt dort „Hintergrundbild“).
- Tiefe Spezialeinstellungen: vorhandene KDE-Einstellungsseiten einbinden statt neu bauen.
- Unterseiten:
  - **Apps → Installierte Apps:** Liste mit Name, Symbol, Größe; Deinstallieren mit einem Klick (Systempakete, AUR, Flatpak, AppImage). Nur echte Apps zeigen, keine Bibliotheken; Reste/Abhängigkeiten sicher mit entfernen.
  - **System → Speicher / Laufwerke:** Laufwerke & Partitionen verständlich anzeigen, „Beim Start automatisch einbinden“ als Schalter, USB-Stick formatieren. Gefährliche Aktionen deutlich absichern.
- Aufwand: 🟠 hoch

### 8. Programme einfach installieren
- Wie bei Windows: **Doppelklick auf die heruntergeladene Datei → installiert**, ohne `chmod` usw.
- `.AppImage` → automatisch ausführbar machen, ins Startmenü eintragen, deinstallierbar.
- `.flatpakref`, `.pkg.tar.zst` → per Doppelklick installieren.
- `.deb` / `.rpm` (nicht passend für CachyOS) → verständlich erklären und die gleiche App aus Paketquellen / Flathub anbieten.
- Aufwand: 🟡 mittel

### 9. Benachrichtigungen wie in Windows
- Problem: Manche Benachrichtigungen bleiben unendlich lange stehen.
- Ziel: Popups verschwinden nach einigen Sekunden immer und landen im Benachrichtigungscenter (Verlauf).
- Aufwand: 🟢 gering (Konfiguration), evtl. 🟡 falls Apps dauerhafte Meldungen erzwingen.

### 10. Fenster-Andocken mit Auswahl („Snap Assist“) – niedrige Priorität
- Wird ein Fenster an eine Bildschirmhälfte angedockt, erscheinen die übrigen Fenster als Vorschau auf der anderen Hälfte → eins anklicken, es füllt die andere Hälfte.
- KDE hat das nicht von Haus aus → als KWin-Skript umsetzbar (vorher prüfen, ob es schon eins gibt).
- Aufwand: 🟡 mittel

---

## Reihenfolge

1. **Basis:** VM, Leisten-/Startmenü-Layout, einheitliche Namen, Design, Benachrichtigungen, Installer/Deinstaller
2. **Stabilität:** Strg+Alt+Entf, Notfall-Dienst, Speicher-Wächter, Taskmanager
3. **Update-Manager**
4. **Einfache App-Installation** (Doppelklick)
5. **Einstellungen** (inkl. Apps deinstallieren, Laufwerke)
6. **Medienplayer**, Snap Assist

Gesamt: mehrere Monate für alles in guter Qualität, erste sichtbare Ergebnisse nach wenigen Tagen.

---

## Testumgebung

- Host: CachyOS, KDE Plasma 6, Wayland, KVM verfügbar.
- VM: **GNOME Boxes** (installiert). CachyOS-ISO (Desktop/KDE) von cachyos.org, VM mit 4 Kernen, 8 GB RAM, 40 GB.
- Nach der Installation sofort Snapshot **„Frisch installiert“** anlegen → nach jedem Test zurücksetzen. ✅ (`frisch-installiert`)
- Details zur Einrichtung und Steuerung: [`tools/vm/README.md`](tools/vm/README.md)

### Erkenntnisse aus der VM-Installation (27.10.2026)
Gute Beispiele dafür, woran Einsteiger scheitern – und was easyLinux später abfangen sollte:
- **Langsames Netz in der VM:** GNOME Boxes erkennt CachyOS nicht und nimmt alte Hardware (rtl8139) → ~100 B/s. Mit virtio volle Geschwindigkeit.
- **Installer bricht beim Schlüsselbund ab:** Ein Schlüssel im aktuellen `archlinux-keyring` hatte einen Zeitstempel in der Zukunft → „could not be locally signed“. Gelöst mit `ignore-time-conflict` während der Installation.
- **Spiegelserver mit 404-Fehlern** (cdn77) – genau das Problem aus Punkt 6 (Update-Manager).
- **Installer-Firewall greift auf die Live-Umgebung über:** Der Schritt „UFW aktivieren“ blockiert danach auch eingehende Verbindungen im Live-System.

## Nächste Schritte

- [x] Host neu starten (Kernel-Update), CachyOS-ISO herunterladen
- [x] VM in GNOME Boxes installieren, Snapshot „Frisch installiert“ anlegen
- [x] Aktuelles Plasma-Layout des Autors auslesen (`~/.config/plasma-org.kde.plasma.desktop-appletsrc` u. a.) und als Basis sichern
- [x] Git-Repo + Projektstruktur anlegen
- [x] `install.sh` / `uninstall.sh` in der VM testen (Startmenü-Symbol der Distribution bleibt jetzt erhalten)
- [ ] Einheitliche App-Namen, Design, mehrere Bildschirme
