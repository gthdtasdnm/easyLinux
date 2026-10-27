import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Dienste: Systemdienste ansehen; Starten/Beenden nur mit Administrator-Passwort
ColumnLayout {
    id: page
    spacing: 0

    property string selected: ""
    property bool selectedRunning: false
    readonly property int colState: Kirigami.Units.gridUnit * 7
    readonly property int colStartup: Kirigami.Units.gridUnit * 7

    function focusList(selectFirst) { list.forceActiveFocus(); if (selectFirst && list.currentIndex < 0 && list.count > 0) list.currentIndex = 0 }

    property list<QtObject> actions: [
        Kirigami.Action {
            text: "Starten"; icon.name: "media-playback-start"
            enabled: page.selected !== "" && !page.selectedRunning
            onTriggered: backend.controlService("start", page.selected)
        },
        Kirigami.Action {
            text: "Beenden"; icon.name: "media-playback-stop"
            enabled: page.selected !== "" && page.selectedRunning
            onTriggered: backend.controlService("stop", page.selected)
        },
        Kirigami.Action {
            text: "Neu starten"; icon.name: "view-refresh"
            enabled: page.selected !== ""
            onTriggered: backend.controlService("restart", page.selected)
        }
    ]

    QQC2.Label {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        Layout.topMargin: 0
        wrapMode: Text.Wrap
        opacity: 0.75
        text: "Dienste laufen im Hintergrund und sorgen z. B. für Netzwerk, Ton und Drucker. Ändern Sie hier nur etwas, wenn Sie wissen, was der Dienst tut."
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.gridUnit
        spacing: 0
        HeaderCell { text: "Name"; column: "name"; alignRight: false; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
        HeaderCell { text: "Beschreibung"; column: "description"; alignRight: false; Layout.fillWidth: true }
        HeaderCell { text: "Status"; column: "status"; alignRight: false; Layout.preferredWidth: page.colState }
        HeaderCell { text: "Starttyp"; column: "startup"; alignRight: false; Layout.preferredWidth: page.colStartup }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.services
            clip: true
            keyNavigationEnabled: true
            currentIndex: -1
            highlightFollowsCurrentItem: false
            reuseItems: true
            onCurrentItemChanged: if (currentItem) currentItem.select()
            delegate: QQC2.ItemDelegate {
                id: row
                required property int index
                required property string unit
                required property string name
                required property string description
                required property string status
                required property bool running
                required property bool failed
                required property string startup
                width: ListView.view.width
                highlighted: page.selected === unit
                focusPolicy: Qt.NoFocus
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                function select() { list.currentIndex = index; page.selected = unit; page.selectedRunning = running }
                onRunningChanged: if (highlighted) page.selectedRunning = running
                onClicked: select()
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (pt) => { row.select(); contextMenu.popup(row, pt.position.x, pt.position.y) }
                }
                contentItem: RowLayout {
                    spacing: 0
                    QQC2.Label { text: row.name; Layout.preferredWidth: Kirigami.Units.gridUnit * 12; Layout.maximumWidth: Kirigami.Units.gridUnit * 12; elide: Text.ElideRight }
                    QQC2.Label { text: row.description; Layout.fillWidth: true; elide: Text.ElideRight; opacity: 0.8 }
                    QQC2.Label {
                        text: row.status
                        Layout.preferredWidth: page.colState; Layout.maximumWidth: page.colState
                        elide: Text.ElideRight
                        color: row.failed ? Kirigami.Theme.negativeTextColor : row.running ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                        opacity: row.running || row.failed ? 1 : 0.6
                    }
                    QQC2.Label { text: row.startup; Layout.preferredWidth: page.colStartup; Layout.maximumWidth: page.colStartup; elide: Text.ElideRight; opacity: 0.8 }
                }
            }
        }
    }

    QQC2.Menu {
        id: contextMenu
        QQC2.MenuItem { action: page.actions[0] }
        QQC2.MenuItem { action: page.actions[1] }
        QQC2.MenuItem { action: page.actions[2] }
    }
}
