import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "Einstellungen"
    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 34
    minimumWidth: Kirigami.Units.gridUnit * 34
    minimumHeight: Kirigami.Units.gridUnit * 22
    visible: true

    property string category: startPage === "installed" ? "apps" : startPage
    property bool showInstalled: startPage === "installed"
    readonly property bool searching: searchField.text.trim().length > 0
    readonly property var categoryInfo: backend.categories.find(c => c.key === root.category) || backend.categories[0]

    Connections {
        target: backend
        function onMessage(text, good) {
            banner.text = text
            banner.type = good ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning
            banner.visible = true
        }
    }

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        titleDelegate: Item {}
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------- Seitenleiste
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.SearchField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Einstellung suchen …"
                        autoAccept: false
                        focus: true
                        onAccepted: if (results.count > 0) backend.open(results.model[0].target)
                    }
                    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
                    Repeater {
                        model: backend.categories
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            highlighted: !root.searching && root.category === modelData.key
                            icon.name: modelData.icon
                            text: modelData.title
                            onClicked: { searchField.text = ""; root.category = modelData.key; root.showInstalled = false }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ---------------- Inhalt
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.gridUnit
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    level: 1
                    text: root.searching ? "Suchergebnisse" : root.showInstalled ? "Installierte Apps" : root.categoryInfo.title
                }
                Kirigami.InlineMessage {
                    id: banner
                    Layout.fillWidth: true
                    visible: false
                    showCloseButton: true
                }

                // Kacheln eines Bereichs bzw. Suchergebnisse
                QQC2.ScrollView {
                    visible: !root.showInstalled || root.searching
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: results
                        clip: true
                        spacing: Kirigami.Units.smallSpacing
                        model: root.searching ? backend.search(searchField.text) : backend.entries(root.category)
                        delegate: EntryDelegate {}
                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            visible: root.searching && results.count === 0
                            icon.name: "edit-find"
                            text: "Nichts gefunden"
                            explanation: "Versuchen Sie ein anderes Wort, z. B. „Bildschirm“, „WLAN“ oder „Drucker“."
                        }
                    }
                }

                // Installierte Apps
                ColumnLayout {
                    visible: root.showInstalled && !root.searching
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Kirigami.SearchField {
                        id: appFilter
                        Layout.fillWidth: true
                        placeholderText: "Apps filtern …"
                    }
                    QQC2.BusyIndicator { visible: backend.loading; Layout.alignment: Qt.AlignHCenter }
                    QQC2.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ListView {
                            clip: true
                            model: backend.apps.filter(a => a.name.toLowerCase().includes(appFilter.text.toLowerCase()))
                            delegate: QQC2.ItemDelegate {
                                required property var modelData
                                width: ListView.view.width
                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.largeSpacing
                                    Kirigami.Icon { source: modelData.icon; fallback: "application-x-executable"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        QQC2.Label { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                                        QQC2.Label { text: modelData.kind; opacity: 0.7; font: Kirigami.Theme.smallFont }
                                    }
                                    QQC2.Label { text: modelData.size; opacity: 0.8 }
                                    QQC2.Button {
                                        text: "Deinstallieren"
                                        icon.name: "edit-delete"
                                        onClicked: { confirm.app = modelData; confirm.open() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Kirigami.PromptDialog {
        id: confirm
        property var app: ({})
        title: "„" + (app.name || "") + "“ deinstallieren?"
        subtitle: "Die App und ihre nicht mehr benötigten Bestandteile werden entfernt. Ihre eigenen Dateien bleiben erhalten."
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action { text: "Deinstallieren"; icon.name: "edit-delete"; onTriggered: { backend.uninstall(confirm.app.source, confirm.app.ident, confirm.app.name); confirm.close() } },
            Kirigami.Action { text: "Abbrechen"; icon.name: "dialog-cancel"; onTriggered: confirm.close() }
        ]
    }

    component EntryDelegate: QQC2.ItemDelegate {
        required property var modelData
        width: ListView.view.width
        onClicked: {
            if (modelData.target === "page:installed") {
                searchField.text = ""
                root.category = "apps"
                root.showInstalled = true
                backend.loadApps()
            } else {
                backend.open(modelData.target)
            }
        }
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon { source: modelData.icon; fallback: "preferences-system"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                QQC2.Label { text: modelData.title; font.bold: true; Layout.fillWidth: true }
                QQC2.Label { text: modelData.subtitle + (root.searching ? "  ·  " + modelData.category : ""); opacity: 0.75; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Kirigami.Icon { source: "go-next"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.6 }
        }
    }

    Component.onCompleted: if (showInstalled) backend.loadApps()
}
