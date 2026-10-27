import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Prozesse: Apps und Hintergrundprozesse mit Prozessor, Arbeitsspeicher, Datenträger
ColumnLayout {
    id: page
    spacing: 0

    signal detailsRequested()

    property string selectedKey: ""
    property string selectedName: ""
    property bool selectedEfficient: false
    readonly property int colStatus: Kirigami.Units.gridUnit * 7
    readonly property int colNum: Kirigami.Units.gridUnit * 6

    function focusList(selectFirst) { list.forceActiveFocus(); if (selectFirst && list.currentIndex < 0 && list.count > 0) list.currentIndex = 0 }

    property list<QtObject> actions: [
        Kirigami.Action {
            text: "Effizienzmodus"
            icon.name: "battery-profile-powersave"
            checkable: true
            checked: page.selectedEfficient
            enabled: page.selectedKey !== ""
            tooltip: "Die App bekommt weniger Rechenzeit, damit andere Apps flüssig bleiben."
            onTriggered: backend.setEfficient(page.selectedKey, checked)
        },
        Kirigami.Action {
            text: "Task beenden"
            icon.name: "process-stop"
            enabled: page.selectedKey !== ""
            onTriggered: backend.endTask(page.selectedKey)
        }
    ]

    Connections {
        target: backend
        function onMessage() { page.selectedKey = ""; list.currentIndex = -1 }
    }

    Shortcut { sequence: "Delete"; enabled: page.visible && page.selectedKey !== ""; onActivated: backend.endTask(page.selectedKey) }

    // Kopfzeile
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.gridUnit
        spacing: 0
        HeaderCell { text: "Name"; column: "name"; alignRight: false; total: " "; Layout.fillWidth: true }
        HeaderCell { text: "Status"; column: "efficient"; alignRight: false; total: " "; Layout.preferredWidth: page.colStatus }
        HeaderCell { text: "Prozessor"; column: "cpu"; total: backend.cpuTotal; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Arbeitsspeicher"; column: "memory"; total: backend.memoryTotal; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Datenträger"; column: "disk"; total: backend.diskTotal; Layout.preferredWidth: page.colNum }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.apps
            clip: true
            focus: true
            keyNavigationEnabled: true
            currentIndex: -1
            highlightFollowsCurrentItem: false
            onCurrentItemChanged: if (currentItem) currentItem.select()
            Keys.onMenuPressed: if (currentItem) contextMenu.popup(currentItem, Kirigami.Units.gridUnit * 4, currentItem.height)
            section.property: "isApp"
            section.delegate: Kirigami.ListSectionHeader {
                width: ListView.view.width
                required property bool section
                text: section ? "Apps" : "Hintergrundprozesse"
            }
            delegate: QQC2.ItemDelegate {
                id: row
                required property int index
                required property string key
                required property string name
                required property string iconName
                required property real cpu
                required property string cpuText
                required property real memory
                required property string memoryText
                required property real disk
                required property string diskText
                required property int count
                required property bool efficient
                width: ListView.view.width
                highlighted: page.selectedKey === key
                focusPolicy: Qt.NoFocus
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                topPadding: 0
                bottomPadding: 0
                function select() {
                    list.currentIndex = index
                    page.selectedKey = key; page.selectedName = name; page.selectedEfficient = efficient
                }
                onEfficientChanged: if (highlighted) page.selectedEfficient = efficient
                onClicked: select()
                onDoubleClicked: backend.endTask(key)
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (pt) => { row.select(); contextMenu.popup(row, pt.position.x, pt.position.y) }
                }
                contentItem: RowLayout {
                    spacing: 0
                    Kirigami.Icon {
                        source: row.iconName
                        fallback: "application-x-executable"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }
                    QQC2.Label {
                        text: row.count > 1 ? row.name + "  (" + row.count + ")" : row.name
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.preferredWidth: page.colStatus
                        Kirigami.Icon {
                            visible: row.efficient
                            source: "battery-profile-powersave"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                        }
                        QQC2.Label { visible: row.efficient; text: "Effizient"; opacity: 0.8; Layout.fillWidth: true }
                        Item { Layout.fillWidth: true }
                    }
                    HeatCell { text: row.cpuText; load: row.cpu / 50; Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.memoryText; load: row.memory / (2 * 1024 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.diskText; load: row.disk / (20 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                }
            }
        }
    }

    QQC2.Menu {
        id: contextMenu
        QQC2.MenuItem { text: "Task beenden"; icon.name: "process-stop"; onTriggered: backend.endTask(page.selectedKey) }
        QQC2.MenuItem {
            text: "Effizienzmodus"
            icon.name: "battery-profile-powersave"
            checkable: true
            checked: page.selectedEfficient
            onTriggered: backend.setEfficient(page.selectedKey, checked)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: "Dateispeicherort öffnen"; icon.name: "folder-open"; onTriggered: backend.openLocation(page.selectedKey) }
        QQC2.MenuItem {
            text: "Zu Details wechseln"
            icon.name: "view-list-text"
            onTriggered: { backend.showDetailsFor(page.selectedKey); page.detailsRequested() }
        }
    }
}
