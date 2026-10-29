import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Für Entwickler (wie Windows 11: System › Für Entwickler): eigene Dienste, Server und Skripte an einer Stelle.
// Pro Eintrag: an/aus, Autostart, im Browser öffnen, Protokoll, Ordner. Lose Programme → „Als Dienst einrichten“.
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    // Neue Dienste tauchen von selbst auf
    Timer { interval: 4000; running: true; repeat: true; onTriggered: developer.refresh() }
    Component.onCompleted: developer.refresh()
    Component.onDestruction: developer.pageClosed()

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            text: "Hier erscheinen Dienste, Server und Skripte, die Sie selbst (oder ein KI-Assistent) eingerichtet haben – "
                + "Programme aus Paketen nicht. Neue Einträge kommen von selbst dazu."
            wrapMode: Text.WordWrap
            opacity: 0.8
        }

        Card {
            iconName: "code-context"
            title: "Coding-Agenten Bescheid geben"
            subtitle: developer.agents
                ? "Claude Code, Codex & Co. legen neue Dienste so an, dass sie hier erscheinen (gefunden: " + developer.agents + ")"
                : "Kein Coding-Agent gefunden (Claude Code, Codex, Gemini CLI)"
            enabled: developer.agents !== "" || developer.agentHint
            QQC2.Switch {
                checked: developer.agentHint
                onToggled: developer.setAgentHint(checked)
            }
        }

        RowLayout {
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.topMargin: Kirigami.Units.largeSpacing
            Kirigami.Heading { level: 3; text: "Meine Dienste"; Layout.fillWidth: true }
            QQC2.CheckBox {
                visible: developer.hiddenCount > 0 || developer.showHidden
                text: "Ausgeblendete zeigen (" + developer.hiddenCount + ")"
                checked: developer.showHidden
                onToggled: developer.setShowHidden(checked)
            }
            QQC2.ToolButton {
                icon.name: "view-refresh"
                text: "Aktualisieren"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                onClicked: developer.refresh()
            }
        }

        QQC2.BusyIndicator { visible: developer.loading; Layout.alignment: Qt.AlignHCenter }

        Kirigami.PlaceholderMessage {
            visible: !developer.loading && developer.entries.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            icon.name: "system-run"
            text: "Noch keine eigenen Dienste"
            explanation: "Sobald ein selbst eingerichteter Dienst oder ein Server aus Ihrem Home-Ordner läuft, erscheint er hier."
        }

        Repeater {
            model: developer.entries
            delegate: ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var e: modelData
                // Überschrift, wenn ein neuer Projektordner beginnt
                readonly property bool firstOfProject: index === 0 || developer.entries[index - 1].project !== e.project
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    visible: row.firstOfProject
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    Layout.rightMargin: Kirigami.Units.gridUnit
                    Layout.topMargin: row.index === 0 ? 0 : Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: "folder"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                    QQC2.Label {
                        text: row.e.projectShort || "Ohne Projektordner"
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                    }
                    QQC2.ToolButton {
                        visible: row.e.project !== ""
                        icon.name: "document-open-folder"
                        text: "Ordner öffnen"
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: developer.openFolder(row.e.project)
                    }
                }

                Card {
                    opacity: row.e.hidden ? 0.6 : 1
                    iconName: row.e.kind === "timer" ? "appointment-new" : row.e.kind === "loose" ? "utilities-terminal"
                            : row.e.failed ? "dialog-error" : "system-run"
                    title: row.e.name
                    subtitle: {
                        const parts = []
                        if (row.e.kind === "loose")
                            parts.push("Läuft lose (nicht als Dienst eingerichtet) – lässt sich nur beenden")
                        else if (row.e.failed)
                            parts.push("Fehler – siehe Protokoll")
                        else if (row.e.kind === "timer")
                            parts.push(row.e.busy ? "Läuft gerade" : row.e.running && row.e.next ? "Nächster Lauf: " + row.e.next : row.e.running ? "Zeitplan aktiv" : "Zeitplan aus")
                        else
                            parts.push(row.e.running ? "Läuft" : "Aus")
                        if (row.e.ports.length)
                            parts.push("Port " + row.e.ports.join(", "))
                        if (row.e.kind !== "loose")
                            parts.push(row.e.unitName + (row.e.user ? "" : " (systemweit, fragt nach dem Passwort)"))
                        return parts.join("  ·  ")
                    }

                    QQC2.Label {
                        visible: row.e["new"]
                        text: "Neu"
                        color: Kirigami.Theme.highlightedTextColor
                        leftPadding: Kirigami.Units.smallSpacing; rightPadding: leftPadding
                        background: Rectangle { color: Kirigami.Theme.highlightColor; radius: Kirigami.Units.cornerRadius }
                    }
                    QQC2.Button {
                        visible: row.e.ports.length > 0 && row.e.running
                        icon.name: "internet-web-browser"
                        text: "Öffnen"
                        QQC2.ToolTip.text: "http://localhost:" + row.e.ports[0] + " im Browser öffnen"
                        QQC2.ToolTip.visible: hovered
                        onClicked: developer.openPort(row.e.ports[0])
                    }
                    QQC2.Button {
                        visible: row.e.kind === "loose"
                        icon.name: "list-add"
                        text: "Als Dienst einrichten"
                        onClicked: makeDialog.ask(row.e)
                    }
                    QQC2.CheckBox {
                        visible: row.e.kind !== "loose"
                        enabled: row.e.canAutostart
                        text: "Autostart"
                        checked: row.e.autostart
                        QQC2.ToolTip.text: row.e.canAutostart
                            ? (row.e.user ? "Beim Anmelden automatisch starten" : "Beim Hochfahren automatisch starten")
                            : "Dieser Dienst wird von einem anderen gestartet und hat keinen eigenen Autostart"
                        QQC2.ToolTip.visible: hovered
                        onToggled: developer.setAutostart(row.e.id, checked)
                    }
                    QQC2.Switch {
                        checked: row.e.running
                        QQC2.ToolTip.text: row.e.kind === "timer" ? "Zeitplan an/aus" : "An/aus"
                        QQC2.ToolTip.visible: hovered
                        // Lose Programme lassen sich nur beenden
                        enabled: row.e.kind !== "loose" || row.e.running
                        onToggled: {
                            if (row.e.kind === "loose") { stopDialog.ask(row.e); checked = true }
                            else developer.setRunning(row.e.id, checked)
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "overflow-menu"
                        text: "Mehr"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: menu.popup()
                        QQC2.Menu {
                            id: menu
                            QQC2.MenuItem {
                                visible: row.e.kind !== "loose"; height: visible ? implicitHeight : 0
                                text: "Neu starten"; icon.name: "view-refresh"
                                onTriggered: developer.restart(row.e.id)
                            }
                            QQC2.MenuItem {
                                visible: row.e.kind !== "loose"; height: visible ? implicitHeight : 0
                                text: "Protokoll anzeigen"; icon.name: "view-list-text"
                                onTriggered: developer.showLog(row.e.id)
                            }
                            QQC2.MenuItem {
                                visible: row.e.file !== ""; height: visible ? implicitHeight : 0
                                text: "Dienst-Datei öffnen"; icon.name: "document-edit"
                                onTriggered: developer.openFile(row.e.file)
                            }
                            QQC2.MenuItem {
                                visible: row.e.project !== ""; height: visible ? implicitHeight : 0
                                text: "Projektordner öffnen"; icon.name: "document-open-folder"
                                onTriggered: developer.openFolder(row.e.project)
                            }
                            QQC2.MenuItem {
                                text: row.e.hidden ? "Wieder einblenden" : "Ausblenden"
                                icon.name: row.e.hidden ? "view-visible" : "view-hidden"
                                onTriggered: developer.setHidden(row.e.id, !row.e.hidden)
                            }
                        }
                    }
                }
            }
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    Kirigami.PromptDialog {
        id: stopDialog
        property var entry: ({})
        function ask(e) { entry = e; open() }
        title: "„" + (entry.name || "") + "“ beenden?"
        subtitle: "Das Programm läuft nicht als Dienst – es lässt sich hier danach nicht wieder starten. "
                + "Tipp: Mit „Als Dienst einrichten“ können Sie es jederzeit an- und ausschalten."
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action { text: "Beenden"; icon.name: "media-playback-stop"; onTriggered: { developer.setRunning(stopDialog.entry.id, false); stopDialog.close() } },
            Kirigami.Action { text: "Abbrechen"; icon.name: "dialog-cancel"; onTriggered: stopDialog.close() }
        ]
    }

    Kirigami.PromptDialog {
        id: makeDialog
        property var entry: ({})
        function ask(e) {
            entry = e
            nameField.text = e.unitName
            descField.text = e.name
            autostartBox.checked = true
            open()
        }
        title: "Als Dienst einrichten"
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: "Einrichten"; icon.name: "dialog-ok-apply"
                enabled: nameField.text.trim() !== ""
                onTriggered: { developer.makeService(makeDialog.entry.id, nameField.text.trim(), descField.text, autostartBox.checked); makeDialog.close() }
            },
            Kirigami.Action { text: "Abbrechen"; icon.name: "dialog-cancel"; onTriggered: makeDialog.close() }
        ]
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            QQC2.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.WordWrap
                text: "Das Programm wird kurz beendet und als Dienst neu gestartet – mit demselben Befehl im selben Ordner. "
                    + "Danach können Sie es hier an- und ausschalten."
            }
            QQC2.Label { text: makeDialog.entry.command || ""; font.family: "monospace"; opacity: 0.7; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: "Name:"
                    validator: RegularExpressionValidator { regularExpression: /[a-zA-Z0-9_-]*/ }
                }
                QQC2.TextField { id: descField; Kirigami.FormData.label: "Beschreibung:" }
                QQC2.CheckBox { id: autostartBox; text: "Beim Anmelden automatisch starten" }
            }
        }
    }
}
