import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Datum & Uhrzeit wie bei Windows 11: oben die aktuelle Uhrzeit, darunter automatisch stellen, Zeitzone, von Hand.
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    signal openTarget(string target)
    property date now: new Date()

    Component.onCompleted: clock.refresh()
    Timer { interval: 1000; running: page.visible; repeat: true; onTriggered: page.now = new Date() }

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            spacing: 0
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            QQC2.Label {
                text: page.now.toLocaleTimeString(Qt.locale("de_DE"), "HH:mm:ss")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
                font.weight: Font.Light
            }
            QQC2.Label { text: page.now.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM yyyy"); opacity: 0.75 }
        }

        Card {
            iconName: "chronometer"
            title: "Uhrzeit automatisch festlegen"
            subtitle: clock.automatic ? (clock.synchronized ? "Mit dem Internet abgeglichen" : "Wird abgeglichen …")
                                      : "Aus – Datum und Uhrzeit werden von Hand gestellt"
            QQC2.Switch { checked: clock.automatic; onToggled: clock.setAutomatic(checked) }
        }
        Card {
            iconName: "view-refresh"
            title: "Uhr synchronisieren"
            subtitle: "Die Uhrzeit sofort mit einem Zeitserver im Internet abgleichen"
            enabled: clock.automatic
            QQC2.Button { text: "Jetzt synchronisieren"; onClicked: clock.syncNow() }
        }
        Card {
            iconName: "preferences-system-time"
            title: "Datum und Uhrzeit manuell festlegen"
            subtitle: clock.automatic ? "Dafür zuerst „Uhrzeit automatisch festlegen“ ausschalten" : "Datum und Uhrzeit selbst eingeben"
            enabled: !clock.automatic
            QQC2.Button { text: "Ändern"; onClicked: manualDialog.open() }
        }
        Card {
            iconName: "globe"
            title: "Zeitzone"
            subtitle: "Bestimmt, welche Uhrzeit angezeigt wird"
            QQC2.ComboBox {
                id: zoneBox
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                model: clock.timezones
                currentIndex: clock.timezones.indexOf(clock.timezone)
                onActivated: clock.setTimezone(currentText)
            }
        }

        Kirigami.Heading { level: 3; text: "Verwandte Einstellungen"; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Card {
            iconName: "preferences-desktop-locale"
            title: "Sprache & Region"
            subtitle: "Datumsformat, 24-Stunden-Uhr, Zahlen und Währung"
            clickable: true
            onClicked: page.openTarget("kcm_regionandlang")
        }
        Card {
            iconName: "preferences-system-time"
            title: "Weitere Uhrzeit-Einstellungen"
            subtitle: "Zeitserver und Hardware-Uhr (für Fortgeschrittene)"
            clickable: true
            onClicked: page.openTarget("kcm_clock")
            Kirigami.Icon { source: "external-link-symbolic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.6 }
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    Kirigami.PromptDialog {
        id: manualDialog
        title: "Datum und Uhrzeit ändern"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onOpened: {
            dateField.text = page.now.toLocaleDateString(Qt.locale("de_DE"), "dd.MM.yyyy")
            timeField.text = page.now.toLocaleTimeString(Qt.locale("de_DE"), "HH:mm")
            dateField.forceActiveFocus()
        }
        onAccepted: clock.setManual(dateField.text, timeField.text)
        Kirigami.FormLayout {
            QQC2.TextField { id: dateField; Kirigami.FormData.label: "Datum (TT.MM.JJJJ):"; onAccepted: manualDialog.accept() }
            QQC2.TextField { id: timeField; Kirigami.FormData.label: "Uhrzeit (SS:MM):"; onAccepted: manualDialog.accept() }
        }
    }
}
