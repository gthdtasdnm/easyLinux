import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Taskmanager wie bei Windows 11: links die Bereiche, oben Suche und Aktionen der Seite.
Kirigami.ApplicationWindow {
    id: root
    title: "Taskmanager"
    width: Kirigami.Units.gridUnit * 56
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 36
    minimumHeight: Kirigami.Units.gridUnit * 22
    visible: false

    // Schließen versteckt nur – so öffnet der Taskmanager beim nächsten Mal sofort.
    onClosing: (close) => { close.accepted = false; root.visible = false }
    onVisibleChanged: { backend.setActive(visible); if (visible) pages.currentItem().focusList() }

    readonly property var tabs: [
        { key: "processes", title: "Prozesse", icon: "view-list-details" },
        { key: "performance", title: "Leistung", icon: "office-chart-area" },
        { key: "autostart", title: "Autostart-Apps", icon: "system-run" },
        { key: "details", title: "Details", icon: "view-list-text" },
        { key: "services", title: "Dienste", icon: "preferences-system-services" }
    ]
    property int tab: 0
    readonly property string page: tabs[tab].key
    onPageChanged: { search.text = ""; backend.setPage(page) }

    function showTab(key) { root.tab = tabs.findIndex(t => t.key === key) }

    Shortcut { sequence: "Escape"; onActivated: root.visible = false }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: root.tab = (root.tab + 1) % root.tabs.length }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length }

    Connections {
        target: backend
        function onMessage(text) { banner.text = text; banner.visible = true; bannerTimer.restart() }
    }

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        titleDelegate: Item {}
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------- Navigation
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.tabs
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            highlighted: root.tab === index
                            icon.name: modelData.icon
                            text: modelData.title
                            onClicked: root.tab = index
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ---------------- Inhalt
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Heading { level: 2; text: root.tabs[root.tab].title }
                    Kirigami.SearchField {
                        id: search
                        visible: root.page !== "performance" && root.page !== "autostart"
                        Layout.fillWidth: true
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                        placeholderText: root.page === "details" ? "Name, PID oder Benutzer suchen …" : "Suchen …"
                        onTextChanged: backend.setFilter(text)
                        Keys.onDownPressed: pages.currentItem().focusList(true)
                        Keys.onReturnPressed: pages.currentItem().focusList(true)
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.Button {
                        text: "Neuen Task ausführen"
                        icon.name: "system-run"
                        visible: root.page === "processes" || root.page === "details"
                        onClicked: runDialog.open()
                    }
                    Repeater {
                        model: pages.currentItem().actions || []
                        delegate: QQC2.Button {
                            required property var modelData
                            action: modelData
                            display: QQC2.AbstractButton.TextBesideIcon
                        }
                    }
                }

                Kirigami.InlineMessage {
                    id: banner
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    type: Kirigami.MessageType.Information
                    showCloseButton: true
                    visible: false
                    Timer { id: bannerTimer; interval: 5000; onTriggered: banner.visible = false }
                }

                StackLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.tab
                    function currentItem() { return children[currentIndex] }

                    ProcessesPage { onDetailsRequested: root.showTab("details") }
                    PerformancePage {}
                    AutostartPage {}
                    DetailsPage {}
                    ServicesPage {}
                }
            }
        }
    }

    Kirigami.PromptDialog {
        id: runDialog
        title: "Neuen Task ausführen"
        subtitle: "Geben Sie den Namen eines Programms ein, z. B. „dolphin“ oder „firefox“."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onOpened: { runField.text = ""; runField.forceActiveFocus() }
        onAccepted: backend.runTask(runField.text)
        QQC2.TextField {
            id: runField
            placeholderText: "Programm"
            onAccepted: runDialog.accept()
        }
    }
}
