import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Leistung: links Prozessor, Speicher, Laufwerke, Netzwerk, GPU – rechts großer Verlauf und Kennzahlen
RowLayout {
    id: page
    spacing: 0

    property string selected: "cpu"
    readonly property var device: backend.devices.find(d => d.key === selected) || backend.devices[0] || null
    property list<QtObject> actions

    function focusList() { devList.forceActiveFocus() }

    QQC2.ScrollView {
        Layout.fillHeight: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        ListView {
            id: devList
            model: backend.devices
            clip: true
            keyNavigationEnabled: true
            spacing: Kirigami.Units.smallSpacing
            onCurrentIndexChanged: if (currentItem) page.selected = currentItem.key
            delegate: QQC2.ItemDelegate {
                id: dev
                required property var modelData
                required property int index
                readonly property string key: modelData.key
                width: ListView.view.width
                highlighted: page.selected === modelData.key
                focusPolicy: Qt.NoFocus
                onClicked: { devList.currentIndex = index; page.selected = modelData.key }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Graph {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
                        history: dev.modelData.history
                        history2: dev.modelData.history2
                        color: dev.modelData.color
                        grid: false
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        QQC2.Label { text: dev.modelData.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        QQC2.Label { text: dev.modelData.subtitle; opacity: 0.75; Layout.fillWidth: true; elide: Text.ElideRight; font: Kirigami.Theme.smallFont }
                    }
                }
            }
        }
    }

    Kirigami.Separator { Layout.fillHeight: true }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.largeSpacing
        visible: page.device !== null

        RowLayout {
            Kirigami.Heading { level: 1; text: page.device ? page.device.title : "" ; Layout.fillWidth: true }
            QQC2.Label {
                text: page.device ? (page.device.details.find(d => d.label === "Modell") || {}).value || "" : ""
                opacity: 0.75
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            }
        }
        RowLayout {
            QQC2.Label {
                text: !page.device ? "" : page.device.kind === "net" ? "Durchsatz (Empfangen / Senden)"
                    : page.device.kind === "disk" ? "Aktive Zeit" : page.device.kind === "memory" ? "Speichernutzung" : "Auslastung in % über 60 Sekunden"
                opacity: 0.75
                Layout.fillWidth: true
            }
            QQC2.Label { text: page.device ? page.device.scaleText : ""; opacity: 0.75 }
        }
        Graph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 8
            history: page.device ? page.device.history : []
            history2: page.device ? page.device.history2 : []
            color: page.device ? page.device.color : "gray"
        }
        RowLayout {
            QQC2.Label { text: "60 Sekunden"; opacity: 0.6; font: Kirigami.Theme.smallFont; Layout.fillWidth: true }
            QQC2.Label { text: "0"; opacity: 0.6; font: Kirigami.Theme.smallFont }
        }
        GridLayout {
            columns: Math.max(2, Math.floor(width / (Kirigami.Units.gridUnit * 11)) * 2)
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Repeater {
                model: page.device ? page.device.details.filter(d => d.label !== "Modell") : []
                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 0
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    QQC2.Label { text: modelData.label; opacity: 0.7; font: Kirigami.Theme.smallFont }
                    QQC2.Label { text: modelData.value; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }
    }
}
