import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "Updates"
    width: Kirigami.Units.gridUnit * 36
    height: Kirigami.Units.gridUnit * 30
    minimumWidth: Kirigami.Units.gridUnit * 24
    minimumHeight: Kirigami.Units.gridUnit * 20
    visible: true

    readonly property string st: backend.state

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Updates"

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // ---------- Status oben
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Layout.preferredWidth
                    source: st === "uptodate" || st === "done" ? "security-high"
                          : st === "error" ? "dialog-error"
                          : backend.securityCount > 0 ? "security-low" : "system-software-update"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        level: 1
                        text: st === "checking" ? "Suche nach Updates …"
                            : st === "uptodate" ? "Ihr Computer ist auf dem neuesten Stand"
                            : st === "available" ? (backend.systemCount + backend.flatpakApps.length) + " Updates verfügbar"
                            : st === "updating" ? "Updates werden installiert"
                            : st === "done" ? "Alle Updates sind installiert"
                            : "Das Update hat nicht geklappt"
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        opacity: 0.8
                        text: st === "available" ? [backend.downloadSize ? "Download: " + backend.downloadSize : "", backend.securityCount > 0 ? backend.securityCount + " wichtige Sicherheitsupdates" : ""].filter(t => t).join(" · ") || backend.lastUpdate
                            : st === "updating" ? "Sie können weiterarbeiten. Bitte schalten Sie den Computer nicht aus."
                            : backend.lastUpdate
                    }
                }
            }

            // ---------- Fortschritt
            ColumnLayout {
                visible: st === "updating"
                Layout.fillWidth: true
                QQC2.ProgressBar { Layout.fillWidth: true; from: 0; to: 1; value: backend.progress; indeterminate: backend.progress < 0.02 }
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: backend.text; Layout.fillWidth: true; elide: Text.ElideRight }
                    QQC2.Label { text: backend.eta; opacity: 0.8 }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: st === "done" && backend.rebootNeeded
                type: Kirigami.MessageType.Warning
                text: "Ein Neustart ist nötig, damit alle Änderungen wirksam werden (z. B. ein neuer Systemkern)."
                actions: [ Kirigami.Action { text: "Jetzt neu starten"; icon.name: "system-reboot"; onTriggered: backend.reboot() } ]
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: st === "error"
                type: Kirigami.MessageType.Error
                text: backend.error
                actions: [ Kirigami.Action { text: "Erneut versuchen"; icon.name: "view-refresh"; onTriggered: backend.update() } ]
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: (st === "available" || st === "updating") && backend.hasSnapshots
                type: Kirigami.MessageType.Information
                text: "Vor dem Update wird automatisch ein Sicherungspunkt angelegt. Falls danach etwas nicht stimmt, können Sie beim Start zum vorherigen Stand zurückkehren."
            }

            // ---------- Hauptknopf
            RowLayout {
                Layout.alignment: Qt.AlignRight
                QQC2.Button {
                    visible: st === "uptodate" || st === "done" || st === "error"
                    text: "Erneut suchen"
                    icon.name: "view-refresh"
                    onClicked: backend.check()
                }
                QQC2.Button {
                    visible: st === "available"
                    text: "Jetzt aktualisieren"
                    icon.name: "system-software-update"
                    highlighted: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    padding: Kirigami.Units.largeSpacing
                    onClicked: backend.update()
                }
            }

            // ---------- Automatische Updates
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: st !== "updating"
                text: "Automatische Updates"
            }
            RowLayout {
                visible: st !== "updating"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Updates automatisch installieren, wenn der Computer gerade nicht benutzt wird"
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        text: "Höchstens einmal am Tag, während der Bildschirm gesperrt ist – nicht im Akkubetrieb und nicht über mobile Daten. "
                            + "Der Computer wird nie von selbst neu gestartet."
                            + (backend.autoEnabled && backend.autoLast ? "\n" + backend.autoLast : "")
                    }
                }
                QQC2.Switch {
                    checked: backend.autoEnabled
                    onToggled: backend.setAuto(checked)
                }
            }

            // ---------- Liste
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: st === "available" && backend.systemCount > 0
                text: "System (" + backend.systemCount + ") – wird immer vollständig aktualisiert"
            }
            Repeater {
                model: st === "available" ? backend.systemPackages : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: modelData.security ? "security-low" : "package-x-generic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                    QQC2.Label { text: modelData.name; Layout.fillWidth: true; font.bold: modelData.security }
                    QQC2.Label { text: modelData.security ? "Sicherheitsupdate" : ""; color: Kirigami.Theme.negativeTextColor }
                    QQC2.Label { text: modelData.old + " → " + modelData.new; opacity: 0.7; elide: Text.ElideMiddle; Layout.maximumWidth: Kirigami.Units.gridUnit * 14 }
                }
            }
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: st === "available" && backend.flatpakApps.length > 0
                text: "Apps (" + backend.flatpakApps.length + ")"
            }
            Repeater {
                model: st === "available" ? backend.flatpakApps : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: modelData.id; fallback: "application-x-executable"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                    QQC2.Label { text: modelData.name; Layout.fillWidth: true }
                    QQC2.Label { text: modelData.version; opacity: 0.7 }
                }
            }
        }
    }
}
