import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Zahl in einer Tabellenzelle, hinterlegt je nach Last gelb bis orange (wie bei Windows)
Rectangle {
    id: heat
    property string text
    property real load: 0          // 0–1
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 2
    color: Qt.rgba(1, 0.78 - 0.35 * Math.min(1, load), 0.15, 0.10 + 0.55 * Math.min(1, load))
    QQC2.Label {
        id: label
        anchors.fill: parent
        anchors.rightMargin: Kirigami.Units.smallSpacing
        text: heat.text
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
    }
}
