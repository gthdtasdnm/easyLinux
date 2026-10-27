import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Details: alle einzelnen Prozesse des Systems (für Fortgeschrittene)
ColumnLayout {
    id: page
    spacing: 0

    property int selectedPid: -1
    property string selectedName: ""
    readonly property int colPid: Kirigami.Units.gridUnit * 4
    readonly property int colState: Kirigami.Units.gridUnit * 8
    readonly property int colUser: Kirigami.Units.gridUnit * 6
    readonly property int colNum: Kirigami.Units.gridUnit * 6

    function focusList(selectFirst) { list.forceActiveFocus(); if (selectFirst && list.currentIndex < 0 && list.count > 0) list.currentIndex = 0 }

    property list<QtObject> actions: [
        Kirigami.Action {
            text: "Task beenden"
            icon.name: "process-stop"
            enabled: page.selectedPid > 0
            onTriggered: backend.endProcess(page.selectedPid, false)
        }
    ]

    Shortcut { sequence: "Delete"; enabled: page.visible && page.selectedPid > 0; onActivated: backend.endProcess(page.selectedPid, false) }
    Shortcut { sequence: "Shift+Delete"; enabled: page.visible && page.selectedPid > 0; onActivated: backend.endProcess(page.selectedPid, true) }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        Layout.topMargin: 0
        visible: backend.detailsFiltered
        text: "Es werden nur die Prozesse der ausgewählten App angezeigt."
        actions: [ Kirigami.Action { text: "Alle anzeigen"; onTriggered: backend.clearPidFilter() } ]
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.gridUnit
        spacing: 0
        HeaderCell { text: "Name"; column: "name"; alignRight: false; Layout.fillWidth: true }
        HeaderCell { text: "PID"; column: "pid"; Layout.preferredWidth: page.colPid }
        HeaderCell { text: "Status"; column: "status"; alignRight: false; Layout.preferredWidth: page.colState; leftPadding: Kirigami.Units.largeSpacing }
        HeaderCell { text: "Benutzer"; column: "user"; alignRight: false; Layout.preferredWidth: page.colUser }
        HeaderCell { text: "Prozessor"; column: "cpu"; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Arbeitsspeicher"; column: "memory"; Layout.preferredWidth: page.colNum }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.processes
            clip: true
            keyNavigationEnabled: true
            currentIndex: -1
            highlightFollowsCurrentItem: false
            reuseItems: true
            onCurrentItemChanged: if (currentItem) currentItem.select()
            Keys.onMenuPressed: if (currentItem) contextMenu.popup(currentItem, Kirigami.Units.gridUnit * 4, currentItem.height)
            delegate: QQC2.ItemDelegate {
                id: row
                required property int index
                required property int pid
                required property string name
                required property string status
                required property string user
                required property real cpu
                required property string cpuText
                required property real memory
                required property string memoryText
                required property string command
                width: ListView.view.width
                highlighted: page.selectedPid === pid
                focusPolicy: Qt.NoFocus
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                topPadding: 0
                bottomPadding: 0
                QQC2.ToolTip.text: command.length > 300 ? command.slice(0, 300) + " …" : command
                QQC2.ToolTip.visible: hovered && command.length > 0
                QQC2.ToolTip.delay: 800
                function select() { list.currentIndex = index; page.selectedPid = pid; page.selectedName = name }
                onClicked: select()
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (pt) => { row.select(); contextMenu.popup(row, pt.position.x, pt.position.y) }
                }
                contentItem: RowLayout {
                    spacing: 0
                    QQC2.Label { text: row.name; Layout.fillWidth: true; elide: Text.ElideRight }
                    QQC2.Label { text: row.pid; Layout.preferredWidth: page.colPid; Layout.maximumWidth: page.colPid; horizontalAlignment: Text.AlignRight; opacity: 0.8 }
                    QQC2.Label { text: row.status; Layout.preferredWidth: page.colState; Layout.maximumWidth: page.colState; leftPadding: Kirigami.Units.largeSpacing; elide: Text.ElideRight; opacity: 0.8 }
                    QQC2.Label { text: row.user; Layout.preferredWidth: page.colUser; Layout.maximumWidth: page.colUser; elide: Text.ElideRight; opacity: 0.8 }
                    HeatCell { text: row.cpuText; load: row.cpu / 50; Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.memoryText; load: row.memory / (2 * 1024 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                }
            }
        }
    }

    QQC2.Menu {
        id: contextMenu
        QQC2.MenuItem { text: "Task beenden"; icon.name: "process-stop"; onTriggered: backend.endProcess(page.selectedPid, false) }
        QQC2.MenuItem { text: "Beenden erzwingen"; icon.name: "edit-delete"; onTriggered: backend.endProcess(page.selectedPid, true) }
        QQC2.Menu {
            title: "Priorität festlegen"
            icon.name: "speedometer"
            QQC2.MenuItem { text: "Hoch (Passwort nötig)"; onTriggered: backend.setPriority(page.selectedPid, -10) }
            QQC2.MenuItem { text: "Höher als normal (Passwort nötig)"; onTriggered: backend.setPriority(page.selectedPid, -5) }
            QQC2.MenuItem { text: "Normal"; onTriggered: backend.setPriority(page.selectedPid, 0) }
            QQC2.MenuItem { text: "Niedriger als normal"; onTriggered: backend.setPriority(page.selectedPid, 5) }
            QQC2.MenuItem { text: "Niedrig"; onTriggered: backend.setPriority(page.selectedPid, 15) }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: "Dateispeicherort öffnen"; icon.name: "folder-open"; onTriggered: backend.openProcessLocation(page.selectedPid) }
    }
}
