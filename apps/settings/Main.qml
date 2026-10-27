import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Einstellungen wie bei Windows 11: links Konto, Suche und Bereiche – rechts die Seite im selben Fenster.
Kirigami.ApplicationWindow {
    id: root
    title: "Einstellungen"
    width: Kirigami.Units.gridUnit * 60
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 40
    minimumHeight: Kirigami.Units.gridUnit * 26
    visible: true

    property string category: "system"
    property string view: "category"          // category | kcm | installed | display | snapassist
    property var entry: null                  // geöffnete Einstellung (für die Überschrift)
    readonly property bool searching: searchField.text.trim().length > 0
    readonly property var categoryInfo: {
        const cats = backend.categories
        for (let i = 0; i < cats.length; i++)
            if (cats[i].key === root.category)
                return cats[i]
        return cats[0]
    }
    readonly property var kcm: kcmLoader.item  // null, wenn die C++-Brücke fehlt

    // Wohin es nach der Rückfrage „Änderungen übernehmen?“ weitergeht
    property var pendingNavigation: null

    function leaveKcm(next) {
        if (root.view === "kcm" && root.kcm && root.kcm.needsSave) {
            root.pendingNavigation = next
            saveDialog.open()
            return
        }
        if (root.kcm)
            root.kcm.close()
        next()
    }

    function showCategory(key) {
        leaveKcm(() => { searchField.text = ""; root.category = key; root.view = "category"; root.entry = null })
    }

    function openEntry(e) {
        if (e.target === "page:installed") {
            leaveKcm(() => { searchField.text = ""; root.category = e.categoryKey; root.view = "installed"; root.entry = e; backend.loadApps() })
        } else if (e.target === "page:display") {
            leaveKcm(() => { searchField.text = ""; root.category = e.categoryKey; root.view = "display"; root.entry = e; display.refresh() })
        } else if (e.target === "page:snapassist") {
            leaveKcm(() => { searchField.text = ""; root.category = e.categoryKey; root.view = "snapassist"; root.entry = e })
        } else if (e.target.startsWith("kcm_") && root.kcm) {
            leaveKcm(() => {
                if (root.kcm.open(e.target)) {
                    searchField.text = ""
                    root.category = e.categoryKey
                    root.view = "kcm"
                    root.entry = e
                } else {
                    backend.open(e.target)  // alte Einstellungsseite – eigenes Fenster
                }
            })
        } else {
            backend.open(e.target)
        }
    }

    function openTarget(target) {
        const e = backend.entryFor(target)
        if (e.target)
            openEntry(e)
        else if (target)
            showCategory(target)
    }

    function goBack() {
        if (root.searching)
            searchField.text = ""
        else if (root.view === "kcm" && root.kcm && root.kcm.module && root.kcm.module.depth > 1)
            root.kcm.module.pop()
        else if (root.view === "kcm" && root.entry && root.entry.target === "kcm_kscreen")
            openTarget("page:display")  // von „Erweiterte Anzeigeeinstellungen“ zurück zur Bildschirm-Seite
        else if (root.view !== "category")
            showCategory(root.category)
    }

    Shortcut { sequences: ["Escape", "Alt+Left", StandardKey.Back]; onActivated: root.goBack() }

    Connections {
        target: backend
        function onMessage(text, good) {
            banner.text = text
            banner.type = good ? Kirigami.MessageType.Positive : Kirigami.MessageType.Warning
            banner.visible = true
        }
        function onNavigate(target) { root.openTarget(target); root.raise(); root.requestActivate() }
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
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    // Konto oben links, wie bei Windows
                    QQC2.ItemDelegate {
                        Layout.fillWidth: true
                        onClicked: root.openTarget("kcm_users")
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            // Rundes Profilbild – oder die Initialen, wenn keins gesetzt ist
                            Rectangle {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: width / 2
                                color: Kirigami.Theme.highlightColor
                                clip: true
                                QQC2.Label {
                                    anchors.centerIn: parent
                                    visible: avatarImage.status !== Image.Ready
                                    text: backend.user.name.split(" ").map(w => w[0]).join("").slice(0, 2).toUpperCase()
                                    color: Kirigami.Theme.highlightedTextColor
                                    font.bold: true
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                                }
                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    source: backend.user.avatar
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    layer.enabled: true
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                QQC2.Label { text: backend.user.name; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                QQC2.Label { text: "Lokales Konto"; opacity: 0.7; font: Kirigami.Theme.smallFont }
                            }
                        }
                    }

                    Kirigami.SearchField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        placeholderText: "Einstellung suchen"
                        autoAccept: false
                        focus: true
                        onAccepted: if (results.count > 0) root.openEntry(results.model[0])
                        Keys.onDownPressed: { results.forceActiveFocus(); results.currentIndex = 0 }
                    }

                    Repeater {
                        model: backend.categories
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            highlighted: !root.searching && root.category === modelData.key
                            icon.name: modelData.icon
                            text: modelData.title
                            onClicked: root.showCategory(modelData.key)
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

                // Überschrift mit Pfad: „System › Bildschirm“
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    Layout.rightMargin: Kirigami.Units.gridUnit
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.ToolButton {
                        visible: root.searching || root.view !== "category"
                        icon.name: "go-previous"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Zurück"
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: root.goBack()
                    }
                    Kirigami.Heading {
                        level: 1
                        text: root.searching ? "Suchergebnisse" : root.categoryInfo.title
                        opacity: !root.searching && root.view !== "category" ? 0.6 : 1
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.searching && root.view !== "category"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.showCategory(root.category)
                        }
                    }
                    Kirigami.Heading {
                        visible: !root.searching && root.view !== "category" && root.entry !== null
                        level: 1
                        text: "›  " + (root.entry ? root.entry.title : "")
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillWidth: true; visible: root.searching || root.view === "category" }
                }

                Kirigami.InlineMessage {
                    id: banner
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    Layout.rightMargin: Kirigami.Units.gridUnit
                    visible: false
                    showCloseButton: true
                }

                // ---- Liste der Einstellungen eines Bereichs bzw. Suchergebnisse
                QQC2.ScrollView {
                    visible: root.searching || root.view === "category"
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: results
                        clip: true
                        spacing: 4
                        leftMargin: Kirigami.Units.gridUnit
                        rightMargin: Kirigami.Units.gridUnit
                        bottomMargin: Kirigami.Units.gridUnit
                        keyNavigationEnabled: true
                        model: root.searching ? backend.search(searchField.text) : backend.entries(root.category)
                        header: Loader {
                            width: ListView.view.width - Kirigami.Units.gridUnit * 2
                            // Höhe ausdrücklich setzen – sonst behält der Loader die alte Höhe
                            height: item ? item.implicitHeight : 0
                            active: !root.searching && root.category === "system"
                            sourceComponent: DeviceCard {}
                        }
                        delegate: EntryCard {}
                        Keys.onReturnPressed: if (currentItem) currentItem.clicked()
                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            visible: root.searching && results.count === 0
                            icon.name: "edit-find"
                            text: "Nichts gefunden"
                            explanation: "Versuchen Sie ein anderes Wort, z. B. „Bildschirm“, „WLAN“ oder „Drucker“."
                        }
                    }
                }

                // ---- Eingebettete KDE-Einstellungsseite
                Loader {
                    id: kcmLoader
                    visible: !root.searching && root.view === "kcm"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    source: typeof kcmHostAvailable !== "undefined" && kcmHostAvailable ? "KcmView.qml" : ""
                }

                // ---- Bildschirm (eigene Seite wie bei Windows)
                Loader {
                    active: !root.searching && root.view === "display"
                    visible: active
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: DisplayPage {
                        onAdvanced: root.openEntry({ title: "Erweiterte Anzeigeeinstellungen", subtitle: "", icon: "preferences-desktop-display",
                                                     target: "kcm_kscreen", categoryKey: "system", category: "System", external: false })
                    }
                }

                // ---- Snap Assist
                Loader {
                    active: !root.searching && root.view === "snapassist"
                    visible: active
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: SnapAssistPage {}
                }

                // ---- Installierte Apps
                ColumnLayout {
                    visible: !root.searching && root.view === "installed"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    Layout.rightMargin: Kirigami.Units.gridUnit
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
                            spacing: 4
                            model: backend.apps.filter(a => a.name.toLowerCase().includes(appFilter.text.toLowerCase()))
                            delegate: QQC2.ItemDelegate {
                                required property var modelData
                                width: ListView.view.width
                                background: CardBackground { hovered: parent.hovered }
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

    Kirigami.PromptDialog {
        id: saveDialog
        title: "Änderungen übernehmen?"
        subtitle: "Auf der Seite „" + (root.entry ? root.entry.title : "") + "“ gibt es Änderungen, die noch nicht übernommen wurden."
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action { text: "Übernehmen"; icon.name: "dialog-ok-apply"; onTriggered: { root.kcm.save(); saveDialog.proceed() } },
            Kirigami.Action { text: "Verwerfen"; icon.name: "edit-delete"; onTriggered: { root.kcm.revert(); saveDialog.proceed() } },
            Kirigami.Action { text: "Abbrechen"; icon.name: "dialog-cancel"; onTriggered: { root.pendingNavigation = null; saveDialog.close() } }
        ]
        function proceed() {
            close()
            const next = root.pendingNavigation
            root.pendingNavigation = null
            root.kcm.close()
            if (next)
                next()
        }
    }

    // Karte im Stil von Windows 11 (abgerundet, leicht abgesetzt)
    component CardBackground: Rectangle {
        property bool hovered: false
        property bool active: false
        radius: Kirigami.Units.cornerRadius
        color: active ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
             : hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.09) : Qt.alpha(Kirigami.Theme.textColor, 0.045)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    }

    component EntryCard: QQC2.ItemDelegate {
        required property var modelData
        required property int index
        width: ListView.view.width - Kirigami.Units.gridUnit * 2
        padding: Kirigami.Units.largeSpacing
        focusPolicy: Qt.NoFocus
        background: CardBackground { hovered: parent.hovered; active: parent.ListView.isCurrentItem && results.activeFocus }
        onClicked: root.openEntry(modelData)
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon { source: modelData.icon; fallback: "preferences-system"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                QQC2.Label { text: modelData.title; Layout.fillWidth: true }
                QQC2.Label {
                    text: modelData.subtitle + (root.searching ? "  ·  " + modelData.category : "")
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            Kirigami.Icon {
                source: modelData.external ? "external-link-symbolic" : "go-next-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                opacity: 0.6
            }
        }
    }

    // Kopf der Seite „System“: Gerätename und Betriebssystem (wie bei Windows)
    component DeviceCard: ColumnLayout {
        spacing: 0
        RowLayout {
            spacing: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
            Kirigami.Icon { source: "computer"; Layout.preferredWidth: Kirigami.Units.iconSizes.huge; Layout.preferredHeight: Layout.preferredWidth }
            ColumnLayout {
                spacing: 0
                QQC2.Label { text: backend.device.hostname; font.bold: true; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3 }
                QQC2.Label { text: backend.device.os + " mit easyLinux"; opacity: 0.7 }
            }
        }
    }

    Component.onCompleted: {
        if (startPage === "installed")
            openTarget("page:installed")
        else
            openTarget(startPage)
    }
}
