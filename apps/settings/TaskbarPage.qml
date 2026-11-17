import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Taskleiste wie bei Windows 11 (Personalisierung › Taskleiste)
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    readonly property var s: taskbar.state
    property bool working: false

    Component.onCompleted: taskbar.refresh()

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            visible: page.s.found === false
            type: Kirigami.MessageType.Warning
            text: "Keine Taskleiste am unteren Bildschirmrand gefunden."
        }

        Kirigami.Heading { level: 3; text: "Verhalten der Taskleiste"; Layout.leftMargin: Kirigami.Units.gridUnit }
        Card {
            iconName: "align-horizontal-center"
            title: "Ausrichtung"
            subtitle: "Start und Apps in der Mitte (wie Windows 11) oder links (wie Windows 10). Die Taskleiste wird dafür kurz neu gestartet."
            QQC2.ComboBox {
                model: ["Zentriert", "Links"]
                currentIndex: page.s.centered ? 0 : 1
                enabled: !page.working
                onActivated: (i) => { page.working = true; Qt.callLater(() => { taskbar.setCentered(i === 0); page.working = false }) }
            }
        }
        Card {
            iconName: "window-minimize"
            title: "Taskleiste automatisch ausblenden"
            subtitle: "Erscheint, wenn die Maus an den unteren Rand fährt"
            QQC2.Switch { checked: page.s.autohide === true; onToggled: taskbar.setAutohide(checked) }
        }
        Card {
            iconName: "group"
            title: "Fenster derselben App zusammenfassen"
            subtitle: "Mehrere Fenster einer App teilen sich ein Symbol"
            QQC2.Switch { checked: page.s.grouping !== false; onToggled: taskbar.setGrouping(checked) }
        }
        Card {
            iconName: "clock"
            title: "Sekunden in der Uhr anzeigen"
            subtitle: "Uhr in der Taskleiste mit Sekunden"
            QQC2.Switch { checked: page.s.seconds === true; onToggled: taskbar.setSeconds(checked) }
        }

        Kirigami.Heading {
            level: 3; text: "Mehrere Bildschirme"
            visible: (page.s.screens || 1) > 1
            Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing
        }
        Card {
            visible: (page.s.screens || 1) > 1
            iconName: "video-display"
            title: "Taskleiste auf allen Bildschirmen anzeigen"
            subtitle: "Jeder Bildschirm bekommt eine eigene Taskleiste mit Start, Apps und Uhr"
            QQC2.Switch { checked: (page.s.bars || 0) > 1; onToggled: taskbar.setAllScreens(checked) }
        }
        Card {
            visible: (page.s.screens || 1) > 1 && (page.s.bars || 0) > 1
            iconName: "window"
            title: "Apps in der Taskleiste anzeigen auf"
            subtitle: "Wo ein geöffnetes Fenster in der Taskleiste erscheint"
            QQC2.ComboBox {
                model: ["Allen Taskleisten", "Taskleiste, auf der das Fenster geöffnet ist"]
                currentIndex: page.s.currentScreenOnly ? 1 : 0
                onActivated: (i) => taskbar.setCurrentScreenOnly(i === 1)
            }
        }

        Kirigami.Heading { level: 3; text: "Weitere Einstellungen"; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Card {
            iconName: "configure"
            title: "Taskleiste frei bearbeiten"
            subtitle: "Elemente hinzufügen, verschieben oder entfernen, Höhe ändern (für Fortgeschrittene)"
            clickable: true
            onClicked: taskbar.editMode()
            Kirigami.Icon { source: "external-link-symbolic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.6 }
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }
}
