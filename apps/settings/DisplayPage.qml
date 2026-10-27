import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Bildschirm wie bei Windows 11: oben die Bildschirme als Kästchen (anklickbar), darunter
// „Mehrere Bildschirme“ und die Einstellungen des gewählten Bildschirms.
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    signal advanced()   // „Erweiterte Anzeigeeinstellungen“ (KDE-Seite zum Anordnen per Ziehen)

    property int selectedId: -1
    readonly property var outputs: display.outputs
    readonly property var current: outputs.find(o => o.id === selectedId) || outputs.find(o => o.primary) || outputs[0] || null
    readonly property var resolution: current ? current.resolutions.find(r => current.resolution === r.width + "x" + r.height) || null : null

    // Vorschau: Bildschirme maßstabsgerecht nebeneinander (gespiegelte liegen übereinander)
    readonly property var bounds: {
        const on = outputs.filter(o => o.enabled)
        const box = { x: 0, y: 0, w: 1, h: 1 }
        if (on.length === 0)
            return box
        const size = o => { const r = o.rotation === "left" || o.rotation === "right"; return [(r ? o.height : o.width) / o.scale, (r ? o.width : o.height) / o.scale] }
        const x0 = Math.min(...on.map(o => o.x)), y0 = Math.min(...on.map(o => o.y))
        return { x: x0, y: y0, w: Math.max(...on.map(o => o.x + size(o)[0])) - x0, h: Math.max(...on.map(o => o.y + size(o)[1])) - y0, size: size }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        // ---------------- Vorschau
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.preferredHeight: Kirigami.Units.gridUnit * 11
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.alternateBackgroundColor
            Item {
                id: stage
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit
                readonly property real k: Math.min(width / page.bounds.w, height / page.bounds.h)
                Repeater {
                    model: page.outputs.filter(o => o.enabled)
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var sz: page.bounds.size ? page.bounds.size(modelData) : [1, 1]
                        readonly property bool mirrored: modelData.mirrorOf !== 0
                        x: (stage.width - page.bounds.w * stage.k) / 2 + (modelData.x - page.bounds.x) * stage.k + (mirrored ? Kirigami.Units.gridUnit * 0.6 : 0)
                        y: (stage.height - page.bounds.h * stage.k) / 2 + (modelData.y - page.bounds.y) * stage.k + (mirrored ? Kirigami.Units.gridUnit * 0.6 : 0)
                        width: sz[0] * stage.k - 4
                        height: sz[1] * stage.k - 4
                        radius: Kirigami.Units.cornerRadius
                        color: page.current && page.current.id === modelData.id ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.25)
                        border.color: Kirigami.Theme.backgroundColor
                        border.width: 2
                        QQC2.Label {
                            anchors.centerIn: parent
                            text: modelData.number
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                            font.bold: true
                            color: page.current && page.current.id === modelData.id ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.selectedId = modelData.id }
                    }
                }
            }
        }

        // Bildschirm wählen (auch ausgeschaltete) – wie die Kästchen oben
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            visible: page.outputs.length > 1
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: page.outputs
                delegate: QQC2.Button {
                    required property var modelData
                    text: modelData.number + "  " + modelData.title + (modelData.enabled ? "" : " – aus")
                    checkable: true
                    checked: page.current && page.current.id === modelData.id
                    onClicked: page.selectedId = modelData.id
                }
            }
        }

        // ---------------- Einstellungen
        Card {
            visible: page.outputs.length > 1
            iconName: "video-display"
            title: "Mehrere Bildschirme"
            subtitle: "Bild auf allen Bildschirmen gleich, erweitert oder nur auf einem"
            QQC2.ComboBox {
                id: multi
                readonly property var choices: [{ value: "extend", text: "Diese Bildschirme erweitern" },
                                                { value: "duplicate", text: "Diese Bildschirme duplizieren" }]
                    .concat(page.outputs.map(o => ({ value: "only:" + o.name, text: "Nur auf " + o.number + " anzeigen" })))
                model: choices
                textRole: "text"
                currentIndex: choices.findIndex(c => c.value === display.mode)
                onActivated: index => display.setMode(choices[index].value)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
        }
        Card {
            visible: page.current !== null && page.current.enabled && page.outputs.filter(o => o.enabled).length > 1
            iconName: "starred-symbolic"
            title: "Als Hauptbildschirm verwenden"
            subtitle: "Hier erscheinen Taskleiste und neue Fenster"
            QQC2.CheckBox {
                checked: page.current !== null && page.current.primary
                // Abwählen geht nicht – stattdessen einen anderen Bildschirm zum Hauptbildschirm machen
                onToggled: if (checked) display.setPrimary(page.current.id); else checked = true
            }
        }
        Card {
            visible: page.current !== null && page.current.enabled
            iconName: "zoom-in"
            title: "Skalierung"
            subtitle: "Größe von Text, Apps und anderen Elementen"
            QQC2.ComboBox {
                model: display.scales
                textRole: "text"
                currentIndex: page.current ? display.scales.findIndex(s => Math.abs(s.value - page.current.scale) < 0.01) : -1
                displayText: currentIndex >= 0 ? currentText : page.current ? Math.round(page.current.scale * 100) + " %" : ""
                onActivated: index => display.setScale(page.current.id, display.scales[index].value)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
        }
        Card {
            visible: page.current !== null && page.current.enabled
            iconName: "view-fullscreen"
            title: "Bildschirmauflösung"
            subtitle: "Passen Sie die Auflösung an Ihren Bildschirm an"
            QQC2.ComboBox {
                model: page.current ? page.current.resolutions : []
                textRole: "text"
                currentIndex: page.current ? page.current.resolutions.findIndex(r => page.current.resolution === r.width + "x" + r.height) : -1
                onActivated: index => display.setModeId(page.current.id, page.current.resolutions[index].rates[0].id)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
        }
        Card {
            visible: page.current !== null && page.current.enabled
            iconName: "object-rotate-right"
            title: "Bildschirmausrichtung"
            subtitle: "Bei gedrehtem Bildschirm Hochformat wählen"
            QQC2.ComboBox {
                model: display.rotations
                textRole: "text"
                currentIndex: page.current ? display.rotations.findIndex(r => r.value === page.current.rotation) : -1
                onActivated: index => display.setRotation(page.current.id, display.rotations[index].value)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
        }
        Card {
            visible: page.resolution !== null && page.resolution.rates.length > 1 && page.current.enabled
            iconName: "chronometer"
            title: "Bildwiederholrate"
            subtitle: "Höhere Werte sorgen für flüssigere Bewegungen"
            QQC2.ComboBox {
                model: page.resolution ? page.resolution.rates : []
                textRole: "text"
                currentIndex: page.resolution ? page.resolution.rates.findIndex(r => r.id === page.current.modeId) : -1
                onActivated: index => display.setModeId(page.current.id, page.resolution.rates[index].id)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
        }

        Kirigami.Heading { level: 3; text: "Verwandte Einstellungen"; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Card {
            iconName: "preferences-desktop-display"
            title: "Erweiterte Anzeigeeinstellungen"
            subtitle: "Bildschirme per Ziehen anordnen, HDR, Farbprofil, Overscan"
            clickable: true
            onClicked: page.advanced()
            Kirigami.Icon { source: "go-next-symbolic"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth; opacity: 0.6 }
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    // Wie Windows: „Diese Anzeigeeinstellungen beibehalten?“ – sonst automatisch zurück
    QQC2.Dialog {
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        visible: display.secondsLeft > 0
        closePolicy: QQC2.Popup.NoAutoClose
        title: "Diese Anzeigeeinstellungen beibehalten?"
        contentItem: QQC2.Label {
            text: "Ohne Antwort wird in " + display.secondsLeft + " Sekunden die vorherige Einstellung wiederhergestellt."
            wrapMode: Text.WordWrap
        }
        footer: QQC2.DialogButtonBox {
            QQC2.Button { text: "Änderungen beibehalten"; highlighted: true; onClicked: display.keep() }
            QQC2.Button { text: "Zurücksetzen"; onClicked: display.revert() }
        }
    }
}
