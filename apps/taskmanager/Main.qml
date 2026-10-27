import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "Taskmanager"
    width: Kirigami.Units.gridUnit * 38
    height: Kirigami.Units.gridUnit * 32
    minimumWidth: Kirigami.Units.gridUnit * 26
    minimumHeight: Kirigami.Units.gridUnit * 20
    visible: false

    // Schließen versteckt nur – so öffnet der Taskmanager beim nächsten Mal sofort.
    onClosing: (close) => { close.accepted = false; root.visible = false }
    onVisibleChanged: { backend.setActive(visible); if (visible) list.forceActiveFocus() }

    property string selectedKey: ""
    property string selectedName: ""

    Shortcut { sequence: "Delete"; enabled: root.selectedKey !== ""; onActivated: backend.endTask(root.selectedKey) }
    Shortcut { sequence: "Escape"; onActivated: root.visible = false }

    Connections {
        target: backend
        function onMessage(text) { banner.text = text; banner.visible = true; bannerTimer.restart(); root.selectedKey = "" }
    }

    pageStack.initialPage: Kirigami.Page {
        title: "Taskmanager"
        padding: Kirigami.Units.largeSpacing

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                UsageCard { title: "Prozessor"; value: backend.cpu; detail: backend.cpu.toFixed(0) + " %"; color: Kirigami.Theme.highlightColor }
                UsageCard { title: "Arbeitsspeicher"; value: backend.memoryPercent; detail: backend.memoryText; color: Kirigami.Theme.positiveTextColor }
            }

            Kirigami.InlineMessage {
                id: banner
                Layout.fillWidth: true
                type: Kirigami.MessageType.Positive
                visible: false
                Timer { id: bannerTimer; interval: 4000; onTriggered: banner.visible = false }
            }

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
                    onCurrentItemChanged: if (currentItem) { root.selectedKey = currentItem.key; root.selectedName = currentItem.name }
                    section.property: "isApp"
                    section.delegate: Kirigami.ListSectionHeader {
                        width: ListView.view.width
                        required property bool section
                        text: section ? "Apps" : "Hintergrundprozesse"
                    }
                    header: RowLayout {
                        width: list.width
                        QQC2.Label { text: "Name"; Layout.fillWidth: true; leftPadding: Kirigami.Units.gridUnit * 2; opacity: 0.7 }
                        QQC2.Label { text: "Prozessor"; Layout.preferredWidth: Kirigami.Units.gridUnit * 5; horizontalAlignment: Text.AlignRight; opacity: 0.7 }
                        QQC2.Label { text: "Speicher"; Layout.preferredWidth: Kirigami.Units.gridUnit * 6; horizontalAlignment: Text.AlignRight; rightPadding: Kirigami.Units.largeSpacing; opacity: 0.7 }
                    }
                    delegate: QQC2.ItemDelegate {
                        required property string key
                        required property string name
                        required property string iconName
                        required property real cpu
                        required property string memoryText
                        required property int count
                        width: ListView.view.width
                        highlighted: root.selectedKey === key
                        focusPolicy: Qt.NoFocus
                        required property int index
                        onClicked: { list.currentIndex = index; root.selectedKey = key; root.selectedName = name }
                        onDoubleClicked: backend.endTask(key)
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            Kirigami.Icon { source: iconName; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
                            QQC2.Label { text: count > 1 ? name + "  (" + count + ")" : name; Layout.fillWidth: true; elide: Text.ElideRight }
                            QQC2.Label { text: cpu.toFixed(1).replace(".", ",") + " %"; Layout.preferredWidth: Kirigami.Units.gridUnit * 5; horizontalAlignment: Text.AlignRight }
                            QQC2.Label { text: memoryText; Layout.preferredWidth: Kirigami.Units.gridUnit * 6; horizontalAlignment: Text.AlignRight }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    text: root.selectedKey ? "Ausgewählt: " + root.selectedName : "Wählen Sie eine App aus, die nicht mehr reagiert."
                }
                QQC2.Button {
                    text: "Task beenden"
                    icon.name: "process-stop"
                    enabled: root.selectedKey !== ""
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    padding: Kirigami.Units.largeSpacing
                    onClicked: backend.endTask(root.selectedKey)
                }
            }
        }
    }

    // Kachel mit Prozent, Text und kleinem Verlaufsdiagramm
    component UsageCard: Kirigami.AbstractCard {
        id: card
        property string title
        property real value
        property string detail
        property color color
        property var history: []
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 6
        onValueChanged: { history = history.concat([value]).slice(-60); canvas.requestPaint() }
        contentItem: ColumnLayout {
            RowLayout {
                QQC2.Label { text: card.title; font.bold: true; Layout.fillWidth: true }
                QQC2.Label { text: card.detail }
            }
            Canvas {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const h = card.history, n = 60
                    if (h.length < 2) return
                    ctx.beginPath()
                    ctx.moveTo(width - (h.length - 1) * width / (n - 1), height)
                    for (let i = 0; i < h.length; i++)
                        ctx.lineTo(width - (h.length - 1 - i) * width / (n - 1), height - h[i] / 100 * height)
                    ctx.lineTo(width, height)
                    ctx.closePath()
                    ctx.fillStyle = Qt.alpha(card.color, 0.25)
                    ctx.fill()
                    ctx.strokeStyle = card.color
                    ctx.lineWidth = 2
                    ctx.stroke()
                }
            }
        }
    }
}
