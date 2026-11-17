import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// App-Verlauf wie bei Windows: Rechenzeit, Datenträger und Netzwerk je App seit einem Stichtag
ColumnLayout {
    id: page
    spacing: 0

    readonly property int colNum: Kirigami.Units.gridUnit * 7

    function focusList(selectFirst) { list.forceActiveFocus() }

    property list<QtObject> actions: [
        Kirigami.Action {
            text: "Verlauf löschen"
            icon.name: "edit-clear-history"
            onTriggered: backend.clearHistory()
        }
    ]

    QQC2.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        text: "Ressourcenverbrauch seit " + backend.historySince + ". Netzwerk zählt nur TCP-Verbindungen."
        wrapMode: Text.WordWrap
        opacity: 0.75
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.gridUnit
        spacing: 0
        HeaderCell { text: "Name"; column: "name"; alignRight: false; Layout.fillWidth: true }
        HeaderCell { text: "CPU-Zeit"; column: "cpu"; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Datenträger"; column: "disk"; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Netzwerk"; column: "net"; Layout.preferredWidth: page.colNum }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.appHistory
            clip: true
            keyNavigationEnabled: true
            delegate: QQC2.ItemDelegate {
                id: row
                required property string name
                required property string iconName
                required property real cpu
                required property string cpuText
                required property real disk
                required property string diskText
                required property real net
                required property string netText
                width: ListView.view.width
                focusPolicy: Qt.NoFocus
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                topPadding: 0
                bottomPadding: 0
                contentItem: RowLayout {
                    spacing: 0
                    Kirigami.Icon {
                        source: row.iconName
                        fallback: "application-x-executable"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }
                    QQC2.Label { text: row.name; Layout.fillWidth: true; elide: Text.ElideRight }
                    HeatCell { text: row.cpuText; load: row.cpu / 3600; Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.diskText; load: row.disk / (10 * 1024 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.netText; load: row.net / (5 * 1024 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                }
            }
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: list.count === 0
                icon.name: "view-history"
                text: "Noch keine Daten"
                explanation: "Der Verlauf wird jede Minute ergänzt, solange Sie angemeldet sind."
            }
        }
    }
}
