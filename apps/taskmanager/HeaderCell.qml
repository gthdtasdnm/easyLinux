import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Spaltenkopf zum Sortieren; optional mit Gesamtwert darüber (wie „12 %“ über „Prozessor“)
QQC2.AbstractButton {
    id: cell
    property string column
    property string total: ""
    property bool alignRight: true
    readonly property bool sorted: backend.sortColumn === column
    implicitHeight: Kirigami.Units.gridUnit * (total ? 2.6 : 1.6)
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    onClicked: backend.sortBy(column)
    background: Rectangle { color: cell.hovered ? Kirigami.Theme.hoverColor : "transparent"; opacity: 0.3 }
    contentItem: ColumnLayout {
        spacing: 0
        QQC2.Label {
            visible: cell.total !== ""
            text: cell.total
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            Layout.fillWidth: true
            horizontalAlignment: cell.alignRight ? Text.AlignRight : Text.AlignLeft
        }
        QQC2.Label {
            text: (cell.sorted ? (backend.sortDescending ? "▼ " : "▲ ") : "") + cell.text
            opacity: 0.75
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: cell.alignRight ? Text.AlignRight : Text.AlignLeft
        }
    }
}
