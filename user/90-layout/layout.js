// easyLinux – Taskleiste & Startmenü
// Basis: Layout des Autors (Plasma-Standardleiste + angeheftete Apps), etwas moderner.
// Wird über org.kde.PlasmaShell.evaluateScript in der laufenden Sitzung ausgeführt.


// Leisten auf dem Hauptbildschirm ersetzen. Leisten auf weiteren Bildschirmen bleiben, wie sie sind –
// eine neue Leiste legt Plasma immer auf dem Hauptbildschirm an.
panels().forEach(function (p) { if (p.screen === 0) p.remove(); });

var panel = new Panel;
panel.location = "bottom";
panel.height = 46;
panel.floating = true;          // schwebende Leiste mit Abstand zum Rand

// Auf sehr breiten Bildschirmen nicht über die volle Breite ziehen (wie Plasma-Standard).
var geo = screenGeometry(panel.screen);
var maxWidth = Math.ceil(geo.height * 21 / 9);
if (geo.width > maxWidth) {
    panel.alignment = "center";
    panel.minimumLength = maxWidth;
    panel.maximumLength = maxWidth;
}

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
// Ein/Aus-Knöpfe im Startmenü wie bei Windows: Energie sparen, Ruhezustand, Neu starten, Herunterfahren.
kickoff.writeConfig("systemFavorites", ["suspend", "hibernate", "reboot", "shutdown"]);
// Startknopf: schlichtes Menüsymbol (drei Balken) statt Distributions-Logo
kickoff.writeConfig("icon", "menu_new-symbolic");

panel.addWidget("org.kde.plasma.pager");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
// Angeheftete Apps: nur Dinge, die es auf jedem frischen System gibt.
tasks.writeConfig("launchers", [
    "applications:easylinux-settings.desktop",
    "preferred://filemanager",
    "preferred://browser",
    "applications:easylinux-taskmanager.desktop"
]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");
