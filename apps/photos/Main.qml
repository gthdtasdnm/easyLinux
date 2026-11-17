import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Fotos wie bei Windows: oben schmale Leiste mit Name und Werkzeugen, in der Mitte das Bild,
// unten die Bilder des Ordners. Doppelklick oder F11 = Vollbild.
Kirigami.ApplicationWindow {
    id: root
    title: photos.name ? photos.name + " – Fotos" : "Fotos"
    width: Kirigami.Units.gridUnit * 56
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 24
    minimumHeight: Kirigami.Units.gridUnit * 16
    visible: true

    property real zoom: 1            // 1 = ins Fenster eingepasst
    property int rotation: 0
    property bool showInfo: false
    property bool slideshow: false
    readonly property bool fullscreen: root.visibility === Window.FullScreen

    function resetView() { zoom = 1; rotation = 0; flick.contentX = 0; flick.contentY = 0 }
    function toggleFullscreen() { root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen }
    function zoomBy(factor, px, py) {
        const old = zoom
        zoom = Math.max(1, Math.min(20, zoom * factor))
        // Am Mauszeiger zoomen
        const fx = px === undefined ? flick.width / 2 : px
        const fy = py === undefined ? flick.height / 2 : py
        flick.contentX = Math.max(0, (flick.contentX + fx) * zoom / old - fx)
        flick.contentY = Math.max(0, (flick.contentY + fy) * zoom / old - fy)
    }

    Connections {
        target: photos
        function onChanged() { root.resetView() }
        function onMessage(text) { root.showPassiveNotification(text) }
    }

    Shortcut { sequences: ["Right", "PgDown"]; onActivated: photos.next() }
    Shortcut { sequences: ["Left", "PgUp"]; onActivated: photos.previous() }
    Shortcut { sequence: "Home"; onActivated: photos.go(0) }
    Shortcut { sequence: "End"; onActivated: photos.go(photos.count - 1) }
    Shortcut { sequences: ["Ctrl++", "Ctrl+="]; onActivated: root.zoomBy(1.25) }
    Shortcut { sequence: "Ctrl+-"; onActivated: root.zoomBy(0.8) }
    Shortcut { sequence: "Ctrl+0"; onActivated: root.resetView() }
    Shortcut { sequence: "Ctrl+R"; onActivated: root.rotation = (root.rotation + 90) % 360 }
    Shortcut { sequences: ["F11", "F"]; onActivated: root.toggleFullscreen() }
    Shortcut { sequence: "Escape"; onActivated: { if (root.slideshow) root.slideshow = false; else if (root.fullscreen) root.toggleFullscreen(); else root.close() } }
    Shortcut { sequence: "Delete"; onActivated: deleteDialog.open() }
    Shortcut { sequence: "Ctrl+C"; onActivated: photos.copy() }
    Shortcut { sequence: "F5"; onActivated: root.slideshow = !root.slideshow }
    Shortcut { sequence: "Alt+Return"; onActivated: root.showInfo = !root.showInfo }

    Timer { interval: 4000; repeat: true; running: root.slideshow; onTriggered: photos.next() }
    onSlideshowChanged: if (slideshow && !fullscreen) toggleFullscreen()

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        titleDelegate: Item {}
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------- Werkzeugleiste
            QQC2.ToolBar {
                Layout.fillWidth: true
                visible: !root.fullscreen
                RowLayout {
                    anchors.fill: parent
                    QQC2.Label {
                        text: photos.count > 0 ? photos.name : "Keine Bilder"
                        font.bold: true
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                    }
                    QQC2.Label {
                        visible: photos.count > 1
                        text: (photos.index + 1) + " von " + photos.count
                        opacity: 0.7
                    }
                    Kirigami.Separator { Layout.fillHeight: true; Layout.margins: Kirigami.Units.smallSpacing }
                    Tool { icon.name: "zoom-out"; text: "Verkleinern (Strg+-)"; enabled: root.zoom > 1; onClicked: root.zoomBy(0.8) }
                    QQC2.ToolButton {
                        text: root.zoom === 1 ? "Eingepasst" : Math.round(root.zoom * 100) + " %"
                        onClicked: root.resetView()
                        QQC2.ToolTip.text: "Ins Fenster einpassen (Strg+0)"
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    Tool { icon.name: "zoom-in"; text: "Vergrößern (Strg++)"; onClicked: root.zoomBy(1.25) }
                    Tool { icon.name: "object-rotate-right"; text: "Drehen (Strg+R)"; onClicked: root.rotation = (root.rotation + 90) % 360 }
                    Tool { icon.name: "edit-delete"; text: "Löschen (Entf)"; enabled: photos.count > 0; onClicked: deleteDialog.open() }
                    Tool { icon.name: "documentinfo"; text: "Dateiinformationen (Alt+Eingabe)"; checkable: true; checked: root.showInfo; onClicked: root.showInfo = !root.showInfo }
                    Tool { icon.name: "media-playback-start"; text: "Diashow (F5)"; enabled: photos.count > 1; onClicked: root.slideshow = true }
                    Tool { icon.name: "view-fullscreen"; text: "Vollbild (F11)"; onClicked: root.toggleFullscreen() }
                    Tool { icon.name: "overflow-menu"; text: "Weitere Optionen"; onClicked: moreMenu.popup() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ---------------- Bild
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.fullscreen ? "black" : Qt.darker(Kirigami.Theme.backgroundColor, Kirigami.Theme.backgroundColor.hslLightness > 0.5 ? 1.08 : 1.3)
                    clip: true

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        contentWidth: width * root.zoom
                        contentHeight: height * root.zoom
                        interactive: root.zoom > 1
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            width: flick.contentWidth
                            height: flick.contentHeight
                            Image {
                                id: image
                                anchors.fill: parent
                                anchors.margins: root.fullscreen ? 0 : Kirigami.Units.largeSpacing
                                visible: !photos.animated
                                source: photos.animated ? "" : photos.currentUrl
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                autoTransform: true      // EXIF-Ausrichtung von Handyfotos beachten
                                smooth: true
                                mipmap: true
                                rotation: root.rotation
                                // Kleine Bilder (Symbole) nicht hochskalieren, solange nicht gezoomt
                                sourceSize.width: root.zoom > 1 ? 0 : Math.max(1, flick.width * Screen.devicePixelRatio)
                                sourceSize.height: root.zoom > 1 ? 0 : Math.max(1, flick.height * Screen.devicePixelRatio)
                            }
                            AnimatedImage {
                                anchors.fill: image
                                visible: photos.animated
                                source: photos.animated ? photos.currentUrl : ""
                                fillMode: Image.PreserveAspectFit
                                rotation: root.rotation
                            }
                        }

                        WheelHandler {
                            // Mausrad zoomt (wie Fotos bei Windows), am Mauszeiger
                            acceptedModifiers: Qt.NoModifier | Qt.ControlModifier
                            onWheel: (ev) => root.zoomBy(ev.angleDelta.y > 0 ? 1.2 : 1 / 1.2, ev.x - flick.contentX, ev.y - flick.contentY)
                        }
                        TapHandler { onDoubleTapped: root.toggleFullscreen() }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: moreMenu.popup() }
                    }

                    QQC2.BusyIndicator { anchors.centerIn: parent; running: image.status === Image.Loading }
                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        visible: photos.count === 0 || image.status === Image.Error
                        icon.name: "image-missing"
                        text: photos.count === 0 ? "Keine Bilder in diesem Ordner" : "Dieses Bild kann nicht angezeigt werden"
                    }

                    // Vor/Zurück-Pfeile am Rand, erscheinen bei Mausbewegung
                    HoverHandler { id: hover }
                    NavButton { anchors.left: parent.left; icon.name: "go-previous"; onClicked: photos.previous() }
                    NavButton { anchors.right: parent.right; icon.name: "go-next"; onClicked: photos.next() }
                }

                // ---------------- Dateiinformationen
                Kirigami.Separator { Layout.fillHeight: true; visible: root.showInfo && !root.fullscreen }
                QQC2.ScrollView {
                    visible: root.showInfo && !root.fullscreen
                    Layout.fillHeight: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                    ColumnLayout {
                        width: Kirigami.Units.gridUnit * 15
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Heading { level: 3; text: "Dateiinformationen"; Layout.margins: Kirigami.Units.largeSpacing }
                        Repeater {
                            model: root.showInfo ? (photos.index, photos.info()) : []
                            delegate: ColumnLayout {
                                required property var modelData
                                spacing: 0
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                Layout.rightMargin: Kirigami.Units.largeSpacing
                                QQC2.Label { text: modelData.label; opacity: 0.7; font: Kirigami.Theme.smallFont }
                                QQC2.Label { text: modelData.value; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; Layout.maximumWidth: Kirigami.Units.gridUnit * 13 }
                            }
                        }
                    }
                }
            }

            // ---------------- Filmstreifen
            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                visible: !root.fullscreen && photos.count > 1
                orientation: ListView.Horizontal
                spacing: Kirigami.Units.smallSpacing
                leftMargin: Kirigami.Units.smallSpacing
                rightMargin: Kirigami.Units.smallSpacing
                clip: true
                model: photos.urls
                currentIndex: photos.index
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width / 2 - Kirigami.Units.gridUnit * 2
                preferredHighlightEnd: width / 2 + Kirigami.Units.gridUnit * 2
                delegate: QQC2.ItemDelegate {
                    required property string modelData
                    required property int index
                    width: Kirigami.Units.gridUnit * 4.5
                    height: strip.height
                    padding: Kirigami.Units.smallSpacing
                    highlighted: index === photos.index
                    focusPolicy: Qt.NoFocus
                    onClicked: photos.go(index)
                    contentItem: Image {
                        source: modelData
                        sourceSize.width: 160
                        sourceSize.height: 120
                        asynchronous: true
                        autoTransform: true
                        fillMode: Image.PreserveAspectCrop
                        cache: true
                    }
                }
            }
        }
    }

    component Tool: QQC2.ToolButton {
        display: QQC2.AbstractButton.IconOnly
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    component NavButton: QQC2.RoundButton {
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Kirigami.Units.largeSpacing
        visible: photos.count > 1
        opacity: hover.hovered || hovered ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        width: Kirigami.Units.gridUnit * 2.5
        height: Kirigami.Units.gridUnit * 4
        radius: Kirigami.Units.cornerRadius
        focusPolicy: Qt.NoFocus
    }

    QQC2.Menu {
        id: moreMenu
        QQC2.MenuItem { text: "Kopieren"; icon.name: "edit-copy"; onTriggered: photos.copy() }
        QQC2.MenuItem { text: "Öffnen mit …"; icon.name: "document-open"; onTriggered: photos.openWith() }
        QQC2.MenuItem { text: "Im Ordner anzeigen"; icon.name: "folder-open"; onTriggered: photos.showInFolder() }
        QQC2.MenuItem { text: "Als Hintergrund festlegen"; icon.name: "preferences-desktop-wallpaper"; onTriggered: photos.setWallpaper() }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: "Diashow"; icon.name: "media-playback-start"; enabled: photos.count > 1; onTriggered: root.slideshow = true }
        QQC2.MenuItem { text: "Löschen"; icon.name: "edit-delete"; onTriggered: deleteDialog.open() }
    }

    Kirigami.PromptDialog {
        id: deleteDialog
        title: "Datei löschen?"
        subtitle: "„" + photos.name + "“ wird in den Papierkorb verschoben."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: photos.delete()
    }
}
