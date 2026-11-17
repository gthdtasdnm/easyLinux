import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Benutzer wie bei Windows: angemeldete Benutzer mit ihrem Verbrauch
ColumnLayout {
    id: page
    spacing: 0

    readonly property int colStatus: Kirigami.Units.gridUnit * 7
    readonly property int colNum: Kirigami.Units.gridUnit * 6
    property list<QtObject> actions

    function focusList(selectFirst) { list.forceActiveFocus() }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.gridUnit
        spacing: 0
        HeaderCell { text: "Benutzer"; column: "name"; alignRight: false; Layout.fillWidth: true }
        HeaderCell { text: "Status"; column: "status"; alignRight: false; Layout.preferredWidth: page.colStatus }
        HeaderCell { text: "Prozesse"; column: "count"; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Prozessor"; column: "cpu"; Layout.preferredWidth: page.colNum }
        HeaderCell { text: "Arbeitsspeicher"; column: "memory"; Layout.preferredWidth: page.colNum }
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.users
            clip: true
            delegate: QQC2.ItemDelegate {
                id: row
                required property string name
                required property string fullName
                required property string status
                required property int count
                required property real cpu
                required property string cpuText
                required property real memory
                required property string memoryText
                width: ListView.view.width
                focusPolicy: Qt.NoFocus
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                contentItem: RowLayout {
                    spacing: 0
                    Kirigami.Icon {
                        source: "user-identity"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        QQC2.Label { text: row.fullName; elide: Text.ElideRight; Layout.fillWidth: true }
                        QQC2.Label { text: row.name; opacity: 0.6; font: Kirigami.Theme.smallFont; visible: row.name !== row.fullName }
                    }
                    QQC2.Label { text: row.status; Layout.preferredWidth: page.colStatus; opacity: 0.8 }
                    QQC2.Label { text: row.count; Layout.preferredWidth: page.colNum; horizontalAlignment: Text.AlignRight; rightPadding: Kirigami.Units.smallSpacing }
                    HeatCell { text: row.cpuText; load: row.cpu / 50; Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                    HeatCell { text: row.memoryText; load: row.memory / (8 * 1024 * 1024 * 1024); Layout.preferredWidth: page.colNum; Layout.fillHeight: true }
                }
            }
        }
    }
}
