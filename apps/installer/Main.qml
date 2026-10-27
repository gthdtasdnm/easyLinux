import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "easyLinux"
    width: Kirigami.Units.gridUnit * 36
    height: Kirigami.Units.gridUnit * 34
    minimumWidth: Kirigami.Units.gridUnit * 28
    minimumHeight: Kirigami.Units.gridUnit * 26
    visible: true

    readonly property string s: backend.state
    property bool confirmRemove: startRemove

    pageStack.initialPage: Kirigami.ScrollablePage {
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
        padding: Kirigami.Units.gridUnit * 1.5

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                spacing: Kirigami.Units.gridUnit
                Kirigami.Icon {
                    source: root.s === "error" ? "dialog-error" : "qrc:/easylinux.svg"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Layout.preferredWidth
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        level: 1
                        text: ({ checking: "easyLinux", notInstalled: "easyLinux installieren", installed: "easyLinux ist installiert",
                                 working: "Einen Moment bitte …", installedDone: "Fertig!", removedDone: "easyLinux wurde entfernt",
                                 error: "Etwas ist schiefgelaufen" })[root.s] || "easyLinux"
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        opacity: 0.75
                        text: "Windows-Gefühl für CachyOS – einfach, übersichtlich und jederzeit wieder entfernbar."
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: backend.error !== "" && root.s !== "error"
                type: Kirigami.MessageType.Warning
                text: backend.error
            }

            // ---------------- Was easyLinux macht
            Kirigami.AbstractCard {
                visible: root.s === "notInstalled"
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label { text: "Das bekommen Sie:"; font.bold: true }
                    Repeater {
                        model: [
                            ["view-list-icons", "Taskleiste und Startmenü wie bei Windows"],
                            ["utilities-system-monitor", "Taskmanager (Strg+Umschalt+Esc) und Strg+Alt+Entf – auch wenn nichts mehr reagiert"],
                            ["preferences-system", "Übersichtliche Einstellungen mit Suche"],
                            ["system-software-update", "Updates mit einem Klick"],
                            ["security-high", "Sicherheit: Firewall, Virenschutz, Sicherungspunkte im Blick"],
                            ["system-software-install", "Programme per Doppelklick installieren"],
                            ["view-split-left-right", "Fenster nebeneinander andocken wie bei Windows"]
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            spacing: Kirigami.Units.largeSpacing
                            Kirigami.Icon { source: modelData[0]; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth }
                            QQC2.Label { text: modelData[1]; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                    }
                }
            }

            QQC2.Label {
                visible: root.s === "notInstalled"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.8
                text: "Ihr Passwort wird einmal abgefragt. Dabei wird auch Ihr System auf den neuesten Stand gebracht – "
                    + "das kann je nach Internetverbindung einige Minuten dauern. Ihre Dateien bleiben unverändert."
            }

            // ---------------- Fortschritt
            ColumnLayout {
                visible: root.s === "working" || root.s === "error"
                Layout.fillWidth: true
                QQC2.Label { visible: root.s === "working"; text: backend.step; font.bold: true }
                QQC2.ProgressBar {
                    visible: root.s === "working"
                    Layout.fillWidth: true
                    indeterminate: backend.progress < 0
                    value: Math.max(0, backend.progress)
                }
                QQC2.Label {
                    visible: root.s === "error"
                    text: backend.error
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    color: Kirigami.Theme.negativeTextColor
                }
                QQC2.CheckBox { id: details; text: "Details anzeigen"; checked: root.s === "error" }
                QQC2.ScrollView {
                    visible: details.checked
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 10
                    QQC2.TextArea {
                        readOnly: true
                        text: backend.log
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: Text.WrapAnywhere
                        onTextChanged: cursorPosition = length
                    }
                }
            }

            // ---------------- Fertig
            QQC2.Label {
                visible: root.s === "installedDone" || root.s === "removedDone"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.s === "installedDone"
                    ? "easyLinux ist installiert. Melden Sie sich jetzt einmal ab und wieder an – dann ist alles aktiv, auch Strg+Alt+Entf."
                    : "Ihr Computer ist wieder wie vorher. Melden Sie sich einmal ab und wieder an, damit alle Änderungen verschwinden."
            }

            // ---------------- Bereits installiert
            ColumnLayout {
                visible: root.s === "installed"
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: root.confirmRemove
                        ? "Soll easyLinux wirklich entfernt werden? Ihre vorherigen Einstellungen (Leiste, Tastenkürzel …) werden wiederhergestellt. Ihre Dateien bleiben unverändert."
                        : "Updates für easyLinux kommen ganz normal mit den Systemupdates. Hier können Sie easyLinux auch wieder entfernen."
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: Kirigami.Units.gridUnit }

            // ---------------- Knöpfe
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    visible: root.s === "notInstalled"
                    text: "Jetzt installieren"
                    icon.name: "run-install"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    font.bold: true
                    padding: Kirigami.Units.largeSpacing * 1.5
                    onClicked: backend.install()
                }
                QQC2.Button {
                    visible: root.s === "installed" && !root.confirmRemove
                    text: "easyLinux entfernen …"
                    icon.name: "edit-delete"
                    onClicked: root.confirmRemove = true
                }
                QQC2.Button {
                    visible: root.s === "installed" && root.confirmRemove
                    text: "Abbrechen"
                    onClicked: root.confirmRemove = false
                }
                QQC2.Button {
                    visible: root.s === "installed" && root.confirmRemove
                    text: "Ja, entfernen"
                    icon.name: "edit-delete"
                    highlighted: true
                    onClicked: backend.remove()
                }
                QQC2.Button {
                    visible: root.s === "error"
                    text: "Erneut versuchen"
                    icon.name: "view-refresh"
                    onClicked: backend.refresh()
                }
                QQC2.Button {
                    visible: root.s === "installedDone" || root.s === "removedDone" || root.s === "installed" && !root.confirmRemove || root.s === "error"
                    text: root.s === "installedDone" || root.s === "removedDone" ? "Später" : "Schließen"
                    onClicked: Qt.quit()
                }
                QQC2.Button {
                    visible: root.s === "installedDone" || root.s === "removedDone"
                    text: "Jetzt abmelden"
                    icon.name: "system-log-out"
                    highlighted: true
                    onClicked: backend.logout()
                }
            }
        }
    }
}
