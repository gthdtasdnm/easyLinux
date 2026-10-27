import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Einstellungs-Karte wie bei Windows 11: Symbol, Titel, Beschreibung – rechts das Bedienelement
QQC2.ItemDelegate {
    id: card
    property string iconName
    property string title
    property string subtitle
    property bool clickable: false
    default property alias controls: slot.data
    Layout.fillWidth: true
    Layout.leftMargin: Kirigami.Units.gridUnit
    Layout.rightMargin: Kirigami.Units.gridUnit
    padding: Kirigami.Units.largeSpacing
    hoverEnabled: clickable
    down: clickable && pressed
    focusPolicy: Qt.NoFocus
    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: card.clickable && card.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.09) : Qt.alpha(Kirigami.Theme.textColor, 0.05)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
    }
    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon { source: card.iconName; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Layout.preferredWidth }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC2.Label { text: card.title; Layout.fillWidth: true; elide: Text.ElideRight }
            QQC2.Label { text: card.subtitle; opacity: 0.7; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
        RowLayout { id: slot }
    }
}
