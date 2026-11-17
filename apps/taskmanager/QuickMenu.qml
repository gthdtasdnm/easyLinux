import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell

// Schnellmenü für Win+X wie bei Windows: unten links über der Taskleiste, dieselben Einträge wie der
// Rechtsklick auf den Startknopf. Pfeiltasten + Eingabe, Esc oder Klick daneben schließt.
Window {
    id: menu
    title: "Schnellmenü"
    flags: Qt.FramelessWindowHint
    visibility: Window.Hidden
    width: Kirigami.Units.gridUnit * 15
    height: column.implicitHeight + Kirigami.Units.smallSpacing * 2
    color: Kirigami.Theme.backgroundColor

    LayerShell.Window.scope: "easylinux-quickmenu"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
    LayerShell.Window.margins.left: Kirigami.Units.smallSpacing
    LayerShell.Window.margins.bottom: Kirigami.Units.smallSpacing
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.wantsToBeOnActiveScreen: true

    signal actionChosen(string action)

    // [Aktion, Symbol, Text] – leere Aktion = Trennlinie
    readonly property var entries: [
        ["installed", "preferences-desktop-apps", "Installierte Apps"],
        ["power", "preferences-system-power-management", "Energieoptionen"],
        ["system", "computer", "System"],
        ["devices", "hwinfo", "Geräte-Manager"],
        ["network", "network-wired", "Netzwerkverbindungen"],
        ["disks", "partitionmanager", "Datenträgerverwaltung"],
        ["", "", ""],
        ["terminal", "utilities-terminal", "Terminal"],
        ["terminal-admin", "utilities-terminal-root", "Terminal (Administrator)"],
        ["", "", ""],
        ["taskmanager", "utilities-system-monitor", "Task-Manager"],
        ["settings", "preferences-system", "Einstellungen"],
        ["explorer", "system-file-manager", "Datei-Explorer"],
        ["search", "search", "Suchen"],
        ["run", "system-run", "Ausführen"],
        ["", "", ""],
        ["lock", "system-lock-screen", "Sperren"],
        ["logout", "system-log-out", "Abmelden"],
        ["reboot", "system-reboot", "Neu starten"],
        ["shutdown", "system-shutdown", "Herunterfahren"],
        ["", "", ""],
        ["desktop", "user-desktop", "Desktop"]
    ].filter(e => e[0] === "" || backend.quickAvailable(e[0]))

    function open() {
        menu.show()
        menu.raise()
        menu.requestActivate()
        Qt.callLater(() => { if (repeater.count) repeater.itemAt(0).forceActiveFocus() })
    }
    function choose(action) {
        menu.hide()
        menu.actionChosen(action)
    }

    // Klick daneben (Fenster verliert den Fokus) schließt das Menü wie bei Windows
    onActiveChanged: if (!active && visible) hideTimer.start()
    Timer { id: hideTimer; interval: 150; onTriggered: if (!menu.active) menu.hide() }

    Shortcut { sequence: "Escape"; onActivated: menu.hide() }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        radius: Kirigami.Units.cornerRadius
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 0
        Repeater {
            id: repeater
            model: menu.entries
            delegate: Loader {
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData[0] === "" ? separatorComponent : entryComponent
                function forceActiveFocus() { if (item) item.forceActiveFocus() }
                Component {
                    id: separatorComponent
                    Item {
                        implicitHeight: Kirigami.Units.smallSpacing * 2 + 1
                        Kirigami.Separator { anchors.verticalCenter: parent.verticalCenter; width: parent.width }
                    }
                }
                Component {
                    id: entryComponent
                    QQC2.ItemDelegate {
                        text: modelData[2]
                        icon.name: modelData[1]
                        highlighted: activeFocus
                        onClicked: menu.choose(modelData[0])
                        Keys.onReturnPressed: menu.choose(modelData[0])
                        Keys.onEnterPressed: menu.choose(modelData[0])
                        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
                        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
                    }
                }
            }
        }
    }
}
