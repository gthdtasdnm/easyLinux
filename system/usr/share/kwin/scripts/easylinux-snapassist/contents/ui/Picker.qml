import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin

// Auswahl in einem freien Bereich: Vorschaubilder der übrigen Fenster, mittig in Reihen angeordnet.
// Nur die Vorschaubilder sind anklickbar – ein Klick daneben bricht ab. Beim Viertel sind zwei Auswahlen
// gleichzeitig offen; Wählen oder Abbrechen in einer schließt beide.
// Fenster von einem anderen Bildschirm tragen ein kleines Bildschirm-Symbol.
// (PlasmaCore.Dialog statt QtQuick-Window: „Window“ bezeichnet in org.kde.kwin ein Programmfenster.)
PlasmaCore.Dialog {
    id: picker
    location: PlasmaCore.Types.Desktop
    backgroundHints: PlasmaCore.Types.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    visible: false
    title: root.pickerTitle

    property var windows: []
    property var zone: null        // { rect, slot, output } – wohin das gewählte Fenster kommt
    property rect area
    property var source: null      // das gerade angedockte Fenster
    property bool settling: false  // kurz nach dem Öffnen: Aktivierungen durch das Andocken selbst ignorieren

    // Anordnung wie eine Fotogalerie: Fenster in Reihen nebeneinander, jedes im eigenen Seitenverhältnis.
    // Gesucht wird die größte Bildhöhe, bei der alle Reihen in die freie Fläche passen – so stehen die
    // Fenster bei breiter Fläche von selbst nebeneinander, bei hoher eher untereinander.
    readonly property int gap: Kirigami.Units.gridUnit * 2.5      // Platz zwischen den Bildern zum Danebenklicken
    readonly property int captionHeight: Kirigami.Units.gridUnit * 2
    readonly property int pad: Kirigami.Units.smallSpacing      // Rahmen um das Vorschaubild
    readonly property var boxes: {
        const W = content.width - gap * 2;
        const H = content.height - heading.height - gap * 3;
        const aspects = windows.map(w => {
            const g = w.frameGeometry;
            return g.height > 0 ? Math.min(2.5, Math.max(0.5, g.width / g.height)) : 1.6;
        });
        if (aspects.length === 0 || W <= 0 || H <= 0)
            return [];
        // Reihen für eine Bildhöhe h bilden; null, wenn es nicht passt
        const pack = h => {
            const rows = [[]];
            let x = 0;
            for (let i = 0; i < aspects.length; i++) {
                const w = h * aspects[i] + pad * 2;
                if (w > W)
                    return null;
                if (x > 0 && x + gap + w > W) {
                    rows.push([]);
                    x = 0;
                }
                x += (x > 0 ? gap : 0) + w;
                rows[rows.length - 1].push(i);
            }
            const total = rows.length * (h + pad * 2 + captionHeight) + (rows.length - 1) * gap;
            return total <= H ? rows : null;
        };
        // Nicht größer als knapp die halbe Höhe – sonst wirkt ein einzelnes Fenster riesig
        let lo = 20, hi = Math.max(20, H * 0.38);
        for (let k = 0; k < 24; k++) {
            const mid = (lo + hi) / 2;
            if (pack(mid)) lo = mid; else hi = mid;
        }
        const h = lo, rows = pack(h) || [aspects.map((_, i) => i)];
        const rowH = h + pad * 2 + captionHeight;
        const top = heading.height + gap * 2 + (H - (rows.length * rowH + (rows.length - 1) * gap)) / 2;
        const result = [];
        rows.forEach((row, r) => {
            const widths = row.map(i => h * aspects[i] + pad * 2);
            const rowW = widths.reduce((a, b) => a + b, 0) + gap * (row.length - 1);
            let x = gap + (W - rowW) / 2;
            row.forEach((i, j) => {
                result.push({ index: i, x: x, y: top + r * (rowH + gap), w: widths[j], h: rowH });
                x += widths[j] + gap;
            });
        });
        return result;
    }

    function show(freeZone, candidates, sourceWindow) {
        picker.windows = candidates;
        picker.zone = freeZone;
        picker.area = freeZone.rect;
        picker.source = sourceWindow;
        content.width = freeZone.rect.width;
        content.height = freeZone.rect.height;
        settling = true;
        visible = true;
        place.tries = 0;
        place.restart();
        settle.restart();
    }
    function close() { visible = false; windows = []; source = null }
    function choose(window) { root.pick(window, picker.zone) }

    mainItem: Rectangle {
        id: content
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)

        // KWin platziert das Fenster beim Anzeigen selbst (beim erneuten Öffnen mittig) – danach an den freien
        // Bereich setzen. Zuerst ein Pixel daneben: hat x schon den Zielwert (vom letzten Mal), ignoriert Qt
        // das Setzen sonst, obwohl KWin das Fenster woanders hingestellt hat.
        Timer {
            id: place
            property int tries: 0
            interval: 30
            repeat: true
            onTriggered: {
                const nudge = tries === 0 ? 1 : 0;
                picker.x = picker.area.x + nudge;
                picker.y = picker.area.y + nudge;
                if (tries++ === 1)
                    picker.requestActivate();
                if (tries >= 10)
                    stop();
            }
        }
        Timer { id: settle; interval: 800; onTriggered: picker.settling = false }

        Connections {
            target: Workspace
            // Benutzer wechselt zu einem anderen Fenster → Auswahl schließen.
            // Das angedockte Fenster selbst wird beim Loslassen der Maus oft noch einmal aktiviert – das zählt nicht,
            // ebenso wenig ein Klick in die zweite Auswahl.
            function onWindowActivated(window) {
                if (!picker.visible || !window || window.caption === picker.title)
                    return;
                if (window === picker.source && picker.settling)
                    return;
                root.closePickers();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: root.closePickers() }  // Klick daneben = abbrechen
        focus: true
        Keys.onEscapePressed: root.closePickers()

        QQC2.Label {
            id: heading
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: picker.gap }
            text: "Welches Fenster soll hierhin?"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: picker.boxes
            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var window: picker.windows[modelData.index]
                readonly property bool elsewhere: window && picker.zone && window.output !== picker.zone.output
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                radius: Kirigami.Units.cornerRadius
                color: hover.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : Qt.alpha(Kirigami.Theme.textColor, 0.06)
                border.color: hover.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.12)
                border.width: hover.hovered ? 2 : 1

                WindowThumbnail {
                    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: caption.top; margins: picker.pad }
                    client: card.window
                }
                Row {
                    id: caption
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    height: picker.captionHeight
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: card.window ? card.window.icon : ""
                        width: Kirigami.Units.iconSizes.small
                        height: width
                    }
                    QQC2.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.window ? card.window.caption : ""
                        width: Math.min(implicitWidth, card.width - Kirigami.Units.gridUnit * (card.elsewhere ? 4 : 2.5))
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.elsewhere
                        source: "video-display"
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        opacity: 0.7
                    }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: picker.choose(card.window) }
            }
        }
    }
}
