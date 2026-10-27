import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin

// Auswahl in der freien Bildschirmhälfte: Vorschaubilder der übrigen Fenster.
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

    function show(freeArea, candidates, left) {
        picker.windows = candidates;
        picker.toLeft = left;
        picker.area = freeArea;
        content.width = freeArea.width;
        content.height = freeArea.height;
        grid.currentIndex = 0;
        visible = true;
        place.restart();
    }
    function close() { visible = false; windows = [] }
    function choose(window) { close(); root.pick(window, picker.toLeft) }

    mainItem: Rectangle {
        id: content
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.9)
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)

        // KWin platziert neue Fenster selbst – danach an die freie Hälfte setzen.
        // (Tastaturfokus gibt KWin Skript-Fenstern nicht; bedient wird mit der Maus.)
        Timer {
            id: place
            interval: 1
            onTriggered: {
                picker.x = picker.area.x;
                picker.y = picker.area.y;
                picker.requestActivate();
                grid.forceActiveFocus();
            }
        }

        Connections {
            target: Workspace
            // Benutzer wechselt zu einem anderen Fenster → Auswahl schließen
            function onWindowActivated(window) {
                if (picker.visible && window && window.caption !== picker.title)
                    picker.close();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: picker.close() }  // Klick daneben = abbrechen

        QQC2.Label {
            id: heading
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Kirigami.Units.gridUnit }
            text: "Welches Fenster soll hierhin?"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            horizontalAlignment: Text.AlignHCenter
        }

        GridView {
            id: grid
            anchors { top: heading.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.gridUnit }
            readonly property int columns: picker.windows.length > 4 || width > height * 1.2 ? 2 : 1
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.min(cellWidth * 0.75, Math.floor(height / Math.max(1, Math.ceil(picker.windows.length / columns))))
            clip: true
            model: picker.windows
            keyNavigationEnabled: true
            Keys.onEscapePressed: picker.close()
            Keys.onReturnPressed: if (currentIndex >= 0) picker.choose(picker.windows[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0) picker.choose(picker.windows[currentIndex])

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool active: hover.hovered || GridView.isCurrentItem

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.cornerRadius
                    color: cell.active ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : "transparent"
                    border.color: cell.active ? Kirigami.Theme.highlightColor : "transparent"
                    border.width: 2

                    WindowThumbnail {
                        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: caption.top; margins: Kirigami.Units.largeSpacing }
                        client: cell.modelData
                    }
                    Row {
                        id: caption
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Kirigami.Units.smallSpacing }
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon { source: cell.modelData.icon; width: Kirigami.Units.iconSizes.small; height: width }
                        QQC2.Label {
                            text: cell.modelData.caption
                            width: Math.min(implicitWidth, cell.width - Kirigami.Units.gridUnit * 3)
                            elide: Text.ElideRight
                        }
                    }
                }
                HoverHandler { id: hover }
                TapHandler { onTapped: picker.choose(cell.modelData) }
            }
        }
    }
}
