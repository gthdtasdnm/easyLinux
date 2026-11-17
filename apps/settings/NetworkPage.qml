import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Netzwerk & Internet wie bei Windows 11: oben der Verbindungsstatus, darunter WLAN, Ethernet, VPN,
// Flugzeugmodus und der Weg zu den erweiterten Einstellungen.
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    signal openTarget(string target)
    property bool showDetails: false

    Component.onCompleted: network.refresh()
    Timer { interval: 5000; running: page.visible; repeat: true; onTriggered: network.refresh() }

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        // ---------------- Status
        Card {
            iconName: network.status.icon || "network-wired"
            title: network.status.title || "…"
            subtitle: network.status.subtitle || ""
            QQC2.Button {
                visible: network.status.online === true
                text: page.showDetails ? "Weniger anzeigen" : "Eigenschaften"
                onClicked: page.showDetails = !page.showDetails
            }
        }
        Repeater {
            model: page.showDetails ? network.devices.filter(d => d.connected) : []
            delegate: Details { required property var modelData; device: modelData }
        }

        // ---------------- WLAN
        Kirigami.Heading { level: 3; text: "WLAN"; visible: network.hasWifi; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Card {
            visible: network.hasWifi
            iconName: network.wifiEnabled ? "network-wireless-on" : "network-wireless-off"
            title: "WLAN"
            subtitle: network.wifiEnabled ? "Verfügbare Netzwerke werden unten angezeigt" : "Ausgeschaltet"
            enabled: !network.airplane
            QQC2.BusyIndicator { visible: network.scanning; running: visible; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
            QQC2.Button {
                visible: network.wifiEnabled
                text: "Aktualisieren"
                icon.name: "view-refresh"
                enabled: !network.scanning
                onClicked: network.scan()
            }
            QQC2.Switch { checked: network.wifiEnabled; onToggled: network.setWifiEnabled(checked) }
        }
        Repeater {
            model: network.hasWifi && network.wifiEnabled ? network.wifiNetworks : []
            delegate: Card {
                id: net
                required property var modelData
                iconName: modelData.icon
                title: modelData.ssid
                subtitle: (modelData.active ? "Verbunden" : modelData.known ? "Gespeichert" : "")
                          + (modelData.active || modelData.known ? " · " : "")
                          + (modelData.secure ? "Gesichert (" + modelData.security + ")" : "Offen – nicht gesichert")
                Kirigami.Icon {
                    visible: modelData.secure
                    source: "object-locked"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    opacity: 0.6
                }
                QQC2.BusyIndicator { visible: network.busy === modelData.ssid; running: visible; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                QQC2.Button {
                    visible: modelData.known && !modelData.active
                    text: "Vergessen"
                    onClicked: network.forgetWifi(modelData.ssid)
                }
                QQC2.Button {
                    text: modelData.active ? "Trennen" : "Verbinden"
                    enabled: network.busy === ""
                    onClicked: modelData.active ? network.disconnectWifi(modelData.ssid) : network.connectWifi(modelData.ssid)
                }
            }
        }
        QQC2.Label {
            visible: network.hasWifi && network.wifiEnabled && network.wifiNetworks.length === 0
            text: network.scanning ? "Suche nach Netzwerken …" : "Keine Netzwerke gefunden."
            opacity: 0.7
            Layout.leftMargin: Kirigami.Units.gridUnit * 2
        }

        // ---------------- Ethernet
        Kirigami.Heading {
            level: 3; text: "Ethernet"
            visible: network.devices.some(d => d.type === "ethernet")
            Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing
        }
        Repeater {
            model: network.devices.filter(d => d.type === "ethernet")
            delegate: Card {
                required property var modelData
                iconName: modelData.connected ? "network-wired-activated" : "network-wired-unavailable"
                title: modelData.connected ? modelData.connection : "Ethernet"
                subtitle: modelData.connected ? "Verbunden" + (modelData.details.find(r => r.label === "Verbindungsgeschwindigkeit")
                              ? " · " + modelData.details.find(r => r.label === "Verbindungsgeschwindigkeit").value : "")
                          : "Kein Kabel eingesteckt"
            }
        }

        // ---------------- VPN
        Kirigami.Heading { level: 3; text: "VPN"; visible: network.vpns.length > 0; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Repeater {
            model: network.vpns
            delegate: Card {
                required property var modelData
                iconName: modelData.active ? "network-vpn" : "network-vpn-disconnected"
                title: modelData.name
                subtitle: modelData.active ? "Verbunden" : "Getrennt"
                QQC2.BusyIndicator { visible: network.busy === modelData.uuid; running: visible; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                QQC2.Switch { checked: modelData.active; onToggled: network.setVpn(modelData.uuid, checked) }
            }
        }

        // ---------------- Weiteres
        Kirigami.Heading { level: 3; text: "Weitere Einstellungen"; Layout.leftMargin: Kirigami.Units.gridUnit; Layout.topMargin: Kirigami.Units.largeSpacing }
        Card {
            iconName: "network-flightmode-on"
            title: "Flugzeugmodus"
            subtitle: "Alle Funkverbindungen (WLAN, Bluetooth, Mobilfunk) ausschalten"
            QQC2.Switch { checked: network.airplane; onToggled: network.setAirplane(checked) }
        }
        Card {
            iconName: "preferences-system-network-proxy"
            title: "Proxy"
            subtitle: "Proxyserver für Internetverbindungen"
            clickable: true
            onClicked: page.openTarget("kcm_proxy")
            Kirigami.Icon { source: "external-link-symbolic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.6 }
        }
        Card {
            iconName: "preferences-system-network"
            title: "Erweiterte Netzwerkeinstellungen"
            subtitle: "Verbindungen bearbeiten, feste IP-Adresse, VPN hinzufügen, Hotspot"
            clickable: true
            onClicked: page.openTarget("kcm_networkmanagement")
            Kirigami.Icon { source: "external-link-symbolic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth; opacity: 0.6 }
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    // Eigenschaften einer Verbindung (IP-Adresse, DNS, MAC …) wie bei Windows
    component Details: Rectangle {
        property var device
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        implicitHeight: grid.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
        GridLayout {
            id: grid
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            QQC2.Label { text: device.type === "wifi" ? "WLAN" : "Ethernet"; font.bold: true; Layout.columnSpan: 2 }
            Repeater {
                model: device.details.length * 2
                delegate: QQC2.Label {
                    required property int index
                    readonly property var row: device.details[Math.floor(index / 2)]
                    text: index % 2 === 0 ? row.label + ":" : row.value
                    opacity: index % 2 === 0 ? 0.7 : 1
                    textFormat: Text.PlainText
                    Layout.fillWidth: index % 2 === 1
                    elide: Text.ElideRight
                }
            }
        }
    }
}
