import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.easylinux.kcmhost

// Zeigt eine KDE-Einstellungsseite (KCM) im Fenster an – samt Unterseiten und
// „Übernehmen“/„Zurücksetzen“, falls die Seite Änderungen nicht sofort anwendet.
ColumnLayout {
    id: view
    spacing: 0

    property var module: null
    property string current: ""
    readonly property bool needsSave: module !== null && module.needsSave
    readonly property bool showButtons: module !== null && (module.buttons & 4) && !module.supportsInstantApply

    KcmHost { id: host }

    // true = eingebettet; false = geht nicht (dann öffnet der Aufrufer ein eigenes Fenster)
    function open(name) {
        if (current === name && module)
            return true
        close()
        if (!host.embeddable(name))
            return false
        const m = host.load(name)
        if (!m)
            return false
        module = m
        current = name
        pages.push(m.mainUi)
        return true
    }
    function close() {
        if (!module)
            return
        const m = module
        module = null
        current = ""
        pages.clear()
        host.unload(m)
    }
    function save() { if (module) module.save() }
    function revert() { if (module) module.load() }

    Connections {
        target: view.module
        ignoreUnknownSignals: true
        function onPagePushed(page) { pages.push(page) }
        function onPageRemoved() { if (pages.depth > 1) pages.pop() }
        function onCurrentIndexChanged(index) { pages.currentIndex = index }
    }

    Kirigami.PageRow {
        id: pages
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
        globalToolBar.showNavigationButtons: depth > 1 ? Kirigami.ApplicationHeaderStyle.ShowBackButton
                                                       : Kirigami.ApplicationHeaderStyle.NoNavigationButtons
        defaultColumnWidth: view.module && view.module.columnWidth > 0 ? view.module.columnWidth : width
        onCurrentIndexChanged: if (view.module && view.module.currentIndex !== currentIndex) view.module.currentIndex = currentIndex
    }

    Kirigami.Separator { Layout.fillWidth: true; visible: view.showButtons }
    RowLayout {
        visible: view.showButtons
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        QQC2.Button {
            visible: view.module !== null && (view.module.buttons & 2)
            text: "Standard"
            icon.name: "edit-undo"
            enabled: view.module !== null && !view.module.representsDefaults
            onClicked: view.module.defaults()
        }
        Item { Layout.fillWidth: true }
        QQC2.Button {
            text: "Zurücksetzen"
            icon.name: "edit-reset"
            enabled: view.needsSave
            onClicked: view.revert()
        }
        QQC2.Button {
            text: "Übernehmen"
            icon.name: "dialog-ok-apply"
            highlighted: true
            enabled: view.needsSave
            onClicked: view.save()
        }
    }
}
