import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Autostart-Apps: was beim Anmelden automatisch startet – mit Schalter zum Ein- und Ausschalten
ColumnLayout {
    id: page
    spacing: 0

    function focusList() { list.forceActiveFocus() }

    property list<QtObject> actions: [
        Kirigami.Action {
            text: "Programm hinzufügen …"
            icon.name: "list-add"
            tooltip: "Öffnet die erweiterte Autostart-Einstellung"
            onTriggered: backend.openKcm("kcm_autostart")
        }
    ]

    QQC2.Label {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        Layout.topMargin: 0
        wrapMode: Text.Wrap
        opacity: 0.75
        text: "Diese Programme starten automatisch beim Anmelden. Weniger Autostart-Apps bedeuten einen schnelleren Start. "
            + "Ausschalten deinstalliert nichts – Sie können das Programm weiterhin selbst öffnen."
    }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: backend.autostartApps
            clip: true
            keyNavigationEnabled: true
            delegate: QQC2.ItemDelegate {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                highlighted: ListView.isCurrentItem
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                onClicked: { list.currentIndex = index; toggle.toggle(); toggle.toggled() }
                Keys.onSpacePressed: { toggle.toggle(); toggle.toggled() }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: row.modelData.icon
                        fallback: "application-x-executable"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Layout.preferredWidth
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        QQC2.Label { text: row.modelData.name; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        QQC2.Label {
                            visible: text !== ""
                            text: row.modelData.comment
                            opacity: 0.7
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    QQC2.Label {
                        text: row.modelData.enabled ? "Aktiviert" : "Deaktiviert"
                        opacity: row.modelData.enabled ? 1 : 0.6
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        horizontalAlignment: Text.AlignRight
                    }
                    QQC2.Switch {
                        id: toggle
                        checked: row.modelData.enabled
                        focusPolicy: Qt.NoFocus
                        onToggled: backend.setAutostart(row.modelData.id, checked)
                    }
                }
            }
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: list.count === 0
                icon.name: "system-run"
                text: "Keine Autostart-Apps"
            }
        }
    }
}
