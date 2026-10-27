import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "Sicherheit"
    width: Kirigami.Units.gridUnit * 46
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 28
    minimumHeight: Kirigami.Units.gridUnit * 24
    visible: true

    readonly property var levelColors: [Kirigami.Theme.positiveTextColor, Kirigami.Theme.neutralTextColor, Kirigami.Theme.negativeTextColor]

    Connections {
        target: backend
        function onMessage(text, good) {
            banner.text = text
            banner.type = good ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning
            banner.visible = true
        }
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Sicherheit"
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
        padding: Kirigami.Units.gridUnit

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // ---------------- Gesamtzustand
            RowLayout {
                spacing: Kirigami.Units.gridUnit
                Kirigami.Icon {
                    source: backend.loading ? "security-medium" : ["security-high", "security-medium", "security-low"][backend.overall]
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Layout.preferredWidth
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        level: 1
                        text: backend.loading ? "Wird geprüft …"
                            : ["Ihr Computer ist geschützt", "Empfehlungen verfügbar", "Handlungsbedarf"][backend.overall]
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        opacity: 0.75
                        text: backend.loading ? "Einen Moment bitte."
                            : ["Alles in Ordnung. Sie müssen nichts tun.",
                               "Ihr Computer ist sicher, aber einige Dinge lassen sich verbessern.",
                               "Bitte kümmern Sie sich um die rot markierten Punkte."][backend.overall]
                    }
                }
                QQC2.Button {
                    icon.name: "view-refresh"
                    text: "Erneut prüfen"
                    enabled: !backend.loading && backend.busy === ""
                    onClicked: backend.refresh()
                }
            }

            Kirigami.InlineMessage {
                id: banner
                Layout.fillWidth: true
                showCloseButton: true
                visible: false
            }

            // Laufende Aktion (Virenschutz einrichten, Firewall einschalten)
            Kirigami.AbstractCard {
                visible: backend.busy !== ""
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    QQC2.Label { text: backend.busy; font.bold: true }
                    QQC2.ProgressBar { Layout.fillWidth: true; value: backend.progress; indeterminate: backend.progress <= 0 }
                }
            }

            // ---------------- Virenprüfung
            Kirigami.AbstractCard {
                visible: backend.scanning || backend.found.length > 0
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.largeSpacing
                    RowLayout {
                        QQC2.BusyIndicator { visible: backend.scanning; running: visible; Layout.preferredHeight: Kirigami.Units.iconSizes.medium }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            QQC2.Label {
                                font.bold: true
                                text: backend.scanning ? "Prüfung läuft: " + backend.scanTarget
                                    : backend.found.length + " Bedrohung" + (backend.found.length !== 1 ? "en" : "") + " gefunden"
                                color: backend.scanning ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                            }
                            QQC2.Label {
                                opacity: 0.75
                                text: backend.scanCount + " Dateien geprüft" + (backend.scanning ? " – das Laden der Virensignaturen dauert beim Start etwa eine halbe Minute." : "")
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                        QQC2.Button { visible: backend.scanning; text: "Abbrechen"; onClicked: backend.cancelScan() }
                    }
                    Repeater {
                        model: backend.found
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Kirigami.Icon { source: "data-warning"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                QQC2.Label { text: modelData.name; font.bold: true; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                QQC2.Label { text: modelData.threat + " · " + modelData.path; opacity: 0.7; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            }
                            QQC2.Button { text: "Quarantäne"; icon.name: "security-high"; highlighted: true; onClicked: backend.handleThreat(modelData.path, "quarantine") }
                            QQC2.Button { text: "Löschen"; icon.name: "edit-delete"; onClicked: backend.handleThreat(modelData.path, "delete") }
                            QQC2.Button { text: "Zulassen"; flat: true; onClicked: backend.handleThreat(modelData.path, "keep") }
                        }
                    }
                }
            }
            // Ergebnis ohne Funde
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !backend.scanning && backend.scanCount > 0 && backend.found.length === 0
                type: Kirigami.MessageType.Positive
                text: "Keine Bedrohungen gefunden (" + backend.scanCount + " Dateien geprüft)."
            }

            // ---------------- Kacheln
            GridLayout {
                Layout.fillWidth: true
                columns: width > Kirigami.Units.gridUnit * 36 ? 2 : 1
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing
                visible: !backend.loading || backend.tiles.length > 0
                Repeater {
                    model: backend.loading ? [] : backend.tiles
                    delegate: Kirigami.AbstractCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: 4
                                radius: 2
                                color: root.levelColors[modelData.level]
                            }
                            Kirigami.Icon {
                                source: modelData.icon
                                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignTop
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                QQC2.Label { text: modelData.title; font.bold: true; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15 }
                                QQC2.Label { text: modelData.status; color: root.levelColors[modelData.level]; font.bold: true }
                                QQC2.Label { text: modelData.text; wrapMode: Text.Wrap; opacity: 0.8; Layout.fillWidth: true }
                                Item { Layout.fillHeight: true }
                                RowLayout {
                                    QQC2.Button {
                                        visible: modelData.action !== ""
                                        text: modelData.action
                                        highlighted: modelData.level > 0
                                        enabled: backend.busy === "" && !backend.scanning
                                        onClicked: backend.act(modelData.target)
                                    }
                                    QQC2.Button {
                                        visible: modelData.key === "virus" && modelData.target === "scan-downloads"
                                        text: "Weitere Prüfungen"
                                        icon.name: "arrow-down"
                                        enabled: !backend.scanning
                                        onClicked: scanMenu.popup()
                                        QQC2.Menu {
                                            id: scanMenu
                                            QQC2.MenuItem { text: "Ordner prüfen …"; icon.name: "folder"; onTriggered: backend.chooseAndScan() }
                                            QQC2.MenuItem { text: "Persönlichen Ordner prüfen (dauert länger)"; icon.name: "user-home"; onTriggered: backend.scanHome() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            QQC2.BusyIndicator { visible: backend.loading; Layout.alignment: Qt.AlignHCenter }

        }
    }
}
