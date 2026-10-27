import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Bildschirm für Strg+Alt+Entf – wie bei Windows: Sperren, Benutzer wechseln, Abmelden,
// Taskmanager und unten rechts Neu starten / Herunterfahren.
Window {
    id: menu
    title: "Sicherheitsoptionen"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    visibility: Window.Hidden
    color: "#f20f1318"

    signal actionChosen(string action)

    function open() {
        menu.showFullScreen()
        menu.raise()
        menu.requestActivate()
        first.forceActiveFocus()
    }
    function choose(action) {
        menu.hide()
        menu.actionChosen(action)
    }

    Shortcut { sequence: "Escape"; onActivated: menu.hide() }

    component MenuButton: QQC2.AbstractButton {
        id: btn
        property string label
        activeFocusOnTab: true
        implicitWidth: Kirigami.Units.gridUnit * 16
        implicitHeight: Kirigami.Units.gridUnit * 2.4
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: btn.down ? "#40ffffff" : (btn.hovered || btn.activeFocus ? "#26ffffff" : "transparent")
            border.color: btn.activeFocus ? "#80ffffff" : "transparent"
        }
        contentItem: QQC2.Label {
            text: btn.label
            color: "white"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
            leftPadding: Kirigami.Units.largeSpacing
            verticalAlignment: Text.AlignVCenter
        }
    }

    component PowerButton: QQC2.AbstractButton {
        id: pbtn
        property string iconName
        property string label
        activeFocusOnTab: true
        implicitWidth: Kirigami.Units.gridUnit * 6
        implicitHeight: Kirigami.Units.gridUnit * 5
        Keys.onReturnPressed: clicked()
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: pbtn.down ? "#40ffffff" : (pbtn.hovered || pbtn.activeFocus ? "#26ffffff" : "transparent")
            border.color: pbtn.activeFocus ? "#80ffffff" : "transparent"
        }
        contentItem: ColumnLayout {
            Kirigami.Icon { source: pbtn.iconName; color: "white"; isMask: true; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
            QQC2.Label { text: pbtn.label; color: "white"; Layout.alignment: Qt.AlignHCenter }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        MenuButton { id: first; label: "Sperren"; onClicked: menu.choose("lock") }
        MenuButton { label: "Benutzer wechseln"; onClicked: menu.choose("switch") }
        MenuButton { label: "Abmelden"; onClicked: menu.choose("logout") }
        MenuButton { label: "Taskmanager"; onClicked: menu.choose("taskmanager") }
        Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
        QQC2.Button {
            text: "Abbrechen"
            Layout.alignment: Qt.AlignHCenter
            onClicked: menu.hide()
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.gridUnit * 2
        PowerButton { iconName: "system-reboot"; label: "Neu starten"; onClicked: menu.choose("reboot") }
        PowerButton { iconName: "system-shutdown"; label: "Herunterfahren"; onClicked: menu.choose("shutdown") }
    }

    QQC2.Label {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.gridUnit * 2
        color: "#b0ffffff"
        text: "Esc: zurück   ·   Reagiert gar nichts mehr? Strg+Alt+Entf noch einmal drücken öffnet die Notfall-Hilfe."
    }
}
