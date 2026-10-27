import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Snap Assist wie bei Windows 11 (System › Multitasking › Fenster andocken): nach dem Andocken eines Fensters
// die übrigen Fenster für die freie Fläche vorschlagen. Alles einzeln abschaltbar.
QQC2.ScrollView {
    id: page
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    readonly property var options: snapAssist.options

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            text: "Ziehen Sie ein Fenster an den linken oder rechten Bildschirmrand (oder drücken Sie Meta + Pfeiltaste), "
                + "um es anzudocken. Snap Assist zeigt danach die übrigen Fenster in der freien Fläche – ein Klick, "
                + "und das Fenster füllt sie aus."
            wrapMode: Text.WordWrap
            opacity: 0.8
        }

        Card {
            iconName: "view-split-left-right"
            title: "Snap Assist"
            subtitle: "Beim Andocken eines Fensters vorschlagen, was daneben angedockt werden kann"
            QQC2.Switch {
                checked: snapAssist.enabled
                onToggled: snapAssist.setEnabled(checked)
            }
        }

        Kirigami.Heading {
            level: 3
            text: "Verhalten"
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.topMargin: Kirigami.Units.largeSpacing
            enabled: snapAssist.enabled
        }
        Option {
            key: "AllScreens"
            iconName: "video-display"
            title: "Fenster von allen Bildschirmen anbieten"
            subtitle: "Auch Fenster von anderen Bildschirmen vorschlagen – sie werden beim Auswählen herübergeholt"
        }
        Option {
            key: "Quarters"
            iconName: "view-grid"
            title: "Auch beim Andocken in eine Ecke"
            subtitle: "Wird ein Fenster in ein Bildschirmviertel gedockt, erscheinen zwei Vorschläge: "
                    + "im Viertel darüber bzw. darunter und auf der anderen Seite"
        }
        Option {
            key: "WhenOccupied"
            iconName: "window-duplicate"
            title: "Auch vorschlagen, wenn die andere Seite schon belegt ist"
            subtitle: "Das gewählte Fenster ersetzt dann das dort angedockte. Windows zeigt in diesem Fall nichts an."
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    component Option: Card {
        id: option
        required property string key
        enabled: snapAssist.enabled
        QQC2.Switch {
            checked: page.options[option.key] === true
            onToggled: snapAssist.setOption(option.key, checked)
        }
    }
}
