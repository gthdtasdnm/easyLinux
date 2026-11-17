// easyLinux – Taskleiste & Startmenü wie bei Windows.
// Wird über org.kde.PlasmaShell.evaluateScript in der laufenden Sitzung ausgeführt.
// apply.sh setzt davor `var RESET = true|false;`:
//   RESET = true   Ersteinrichtung: Leiste auf dem Hauptbildschirm neu anlegen
//   RESET = false  nur Bildschirme ohne Leiste ergänzen und bestehende Leisten angleichen,
//                  angeheftete Apps und eigene Widgets bleiben erhalten

var DEFAULT_LAUNCHERS = [
    "applications:easylinux-settings.desktop",
    "preferred://filemanager",
    "preferred://browser",
    "applications:easylinux-taskmanager.desktop"
];

function findWidget(panel, type) {
    var w = panel.widgets(type);
    return w.length ? w[0] : null;
}

// Wie Windows: fest am Rand, volle Breite, keine schwebende Leiste, die beim Maximieren springt.
function windowsStyle(panel) {
    panel.location = "bottom";
    panel.height = 48;
    panel.floating = false;
    panel.hiding = "none";
    panel.alignment = "left";
    panel.lengthMode = "fill";
}

function setupKickoff(kickoff) {
    kickoff.currentConfigGroup = ["General"];
    // Ein/Aus-Knöpfe wie bei Windows: Energie sparen, Ruhezustand, Neu starten, Herunterfahren.
    kickoff.writeConfig("systemFavorites", ["suspend", "hibernate", "reboot", "shutdown"]);
    kickoff.writeConfig("icon", "menu_new-symbolic");
}

function setupTasks(tasks, launchers) {
    tasks.currentConfigGroup = ["General"];
    if (launchers) tasks.writeConfig("launchers", launchers);
    // Windows-Standard: jede Leiste zeigt alle Programme, Gruppen per Klick als Vorschau.
    tasks.writeConfig("showOnlyCurrentScreen", false);
    tasks.writeConfig("showOnlyCurrentDesktop", false);
}

// Hauptleiste: Start, Programme, Infobereich, Uhr, Desktop anzeigen.
function addMainPanel(screen, launchers) {
    var p = new Panel;
    if (p.screen !== screen) p.screen = screen;
    windowsStyle(p);
    setupKickoff(p.addWidget("org.kde.plasma.kickoff"));
    setupTasks(p.addWidget("org.kde.plasma.icontasks"), launchers);
    p.addWidget("org.kde.plasma.marginsseparator");
    p.addWidget("org.kde.plasma.systemtray");
    p.addWidget("org.kde.plasma.digitalclock");
    p.addWidget("org.kde.plasma.showdesktop");
    return p;
}

// Leiste auf weiteren Bildschirmen wie bei Windows 11: Start, Programme, Uhr – ohne Infobereich.
function addSecondaryPanel(screen, launchers) {
    var p = new Panel;
    p.screen = screen;
    windowsStyle(p);
    setupKickoff(p.addWidget("org.kde.plasma.kickoff"));
    setupTasks(p.addWidget("org.kde.plasma.icontasks"), launchers);
    p.addWidget("org.kde.plasma.marginsseparator");
    p.addWidget("org.kde.plasma.digitalclock");
    p.addWidget("org.kde.plasma.showdesktop");
    return p;
}

var bars = panels().filter(function (p) { return p.location === "bottom"; });

if (RESET) {
    panels().forEach(function (p) { if (p.screen === 0) p.remove(); });
    bars = panels().filter(function (p) { return p.location === "bottom"; });
    addMainPanel(0, DEFAULT_LAUNCHERS);
}

// Angeheftete Apps der Hauptleiste übernehmen, damit alle Leisten gleich aussehen.
var launchers = DEFAULT_LAUNCHERS;
var main = panels().filter(function (p) { return p.screen === 0 && p.location === "bottom"; })[0];
if (main) {
    var mt = findWidget(main, "org.kde.plasma.icontasks");
    if (mt) {
        mt.currentConfigGroup = ["General"];
        var l = mt.readConfig("launchers", []);
        if (l && l.length) launchers = l;
    }
}

panels().forEach(function (p) {
    if (p.location !== "bottom") return;
    windowsStyle(p);
    // Arbeitsflächen-Umschalter gibt es bei Windows nicht in der Leiste.
    p.widgets("org.kde.plasma.pager").forEach(function (w) { w.remove(); });
    var t = findWidget(p, "org.kde.plasma.icontasks");
    if (t) setupTasks(t, null);
});

var created = [];
for (var s = 0; s < screenCount; s++) {
    var has = panels().some(function (p) { return p.screen === s; });
    if (has) continue;
    if (s === 0) addMainPanel(0, launchers); else addSecondaryPanel(s, launchers);
    created.push(s);
}
print("easylinux-layout: neu auf Bildschirm " + created.join(",") + "\n");
