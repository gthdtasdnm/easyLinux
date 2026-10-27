import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin

// Auswahl in der freien Bildschirmhälfte: Vorschaubilder der übrigen Fenster, als Raster mittig angeordnet.
// Nur die Vorschaubilder sind anklickbar – ein Klick daneben bricht ab.
// (PlasmaCore.Dialog statt QtQuick-Window: „Window“ bezeichnet in org.kde.kwin ein Programmfenster.)
PlasmaCore.Dialog {
    id: picker
    location: PlasmaCore.Types.Desktop
    backgroundHints: PlasmaCore.Types.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    visible: false
    title: root.pickerTitle

    property var windows: []
    property bool toLeft: false
    property rect area
    property var source: null      // das gerade angedockte Fenster
    property bool settling: false  // kurz nach dem Öffnen: Aktivierungen durch das Andocken selbst ignorieren

    // Raster wie bei Windows: möglichst große Vorschaubilder, aber nicht breiter als knapp die halbe
    // Fläche – bei gleicher Größe lieber nebeneinander als untereinander
    readonly property real ratio: 16 / 10
    readonly property int gap: Kirigami.Units.gridUnit
    readonly property int captionHeight: Kirigami.Units.gridUnit * 2
    readonly property var layout: {
        const n = Math.max(1, windows.length);
        const w = content.width - gap * 2, h = content.height - heading.height - gap * 3;
        const maxW = Math.min(w * 0.45, Kirigami.Units.gridUnit * 22);
        let best = { cols: 1, size: 0 };
        for (let cols = 1; cols <= n; cols++) {
            const rows = Math.ceil(n / cols);
            const byWidth = (w - gap * (cols - 1)) / cols;
            const byHeight = ((h - gap * (rows - 1)) / rows - captionHeight) * ratio;
            const size = Math.min(maxW, byWidth, byHeight);
            if (size >= best.size - 1)
                best = { cols: cols, size: size };
        }
        return best;
    }

    function show(freeArea, candidates, left, sourceWindow) {
        picker.windows = candidates;
        picker.toLeft = left;
        picker.area = freeArea;
        picker.source = sourceWindow;
        content.width = freeArea.width;
        content.height = freeArea.height;
        settling = true;
        visible = true;
        place.restart();
        settle.restart();
    }
    function close() { visible = false; windows = []; source = null }
    function choose(window) { close(); root.pick(window, picker.toLeft) }

    mainItem: Rectangle {
        id: content
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)

        // KWin platziert neue Fenster selbst – danach an die freie Hälfte setzen.
        Timer {
            id: place
            interval: 1
            onTriggered: { picker.x = picker.area.x; picker.y = picker.area.y; picker.requestActivate() }
        }
        Timer { id: settle; interval: 500; onTriggered: picker.settling = false }

        Connections {
            target: Workspace
            // Benutzer wechselt zu einem anderen Fenster → Auswahl schließen.
            // Das angedockte Fenster selbst wird beim Loslassen der Maus oft noch einmal aktiviert – das zählt nicht.
            function onWindowActivated(window) {
                if (!picker.visible || !window || window.caption === picker.title)
                    return;
                if (window === picker.source && picker.settling)
                    return;
                picker.close();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: picker.close() }  // Klick daneben = abbrechen

        QQC2.Label {
            id: heading
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: picker.gap }
            text: "Welches Fenster soll hierhin?"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            horizontalAlignment: Text.AlignHCenter
        }

        Grid {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: heading.height / 2
            columns: picker.layout.cols
            spacing: picker.gap

            Repeater {
                model: picker.windows
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: picker.layout.size
                    height: picker.layout.size / picker.ratio + picker.captionHeight
                    radius: Kirigami.Units.cornerRadius
                    color: hover.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : Qt.alpha(Kirigami.Theme.textColor, 0.06)
                    border.color: hover.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.12)
                    border.width: hover.hovered ? 2 : 1

                    WindowThumbnail {
                        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: caption.top; margins: Kirigami.Units.smallSpacing }
                        client: card.modelData
                    }
                    Row {
                        id: caption
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        height: picker.captionHeight
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: card.modelData.icon
                            width: Kirigami.Units.iconSizes.small
                            height: width
                        }
                        QQC2.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.caption
                            width: Math.min(implicitWidth, card.width - Kirigami.Units.gridUnit * 3)
                            elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: picker.choose(card.modelData) }
                }
            }
        }
    }
}
