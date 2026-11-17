import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami

// Medienplayer wie bei Windows 11: Bild füllt das Fenster, unten eine Steuerleiste, die sich beim
// Zuschauen nach kurzer Zeit ausblendet. Bei Musik: großes Cover und die Titel des Ordners.
Kirigami.ApplicationWindow {
    id: root
    title: playlist.title ? playlist.title + " – Medienplayer" : "Medienplayer"
    width: Kirigami.Units.gridUnit * 52
    height: Kirigami.Units.gridUnit * 32
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 14
    visible: true
    color: "black"

    readonly property bool fullscreen: root.visibility === Window.FullScreen
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    property bool controlsVisible: true
    readonly property bool showControls: controlsVisible || !playing || playlist.isAudio || bar.hovered

    function toggleFullscreen() { root.visibility = root.fullscreen ? Window.Windowed : Window.FullScreen }
    function poke() { root.controlsVisible = true; hideTimer.restart() }
    function seek(deltaMs) { player.position = Math.max(0, Math.min(player.duration, player.position + deltaMs)); poke() }
    function togglePlay() { root.playing ? player.pause() : player.play(); poke() }

    Settings { id: settings; category: "Medienplayer"; property real volume: 0.8; property bool muted: false }

    MediaPlayer {
        id: player
        source: playlist.source
        videoOutput: video
        audioOutput: AudioOutput { id: audio; volume: settings.volume; muted: settings.muted }
        onSourceChanged: if (source != "") play()
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && !playlist.next()) root.controlsVisible = true
        onErrorOccurred: (error, text) => root.showPassiveNotification("Kann nicht abgespielt werden: " + text, "long")
    }

    Timer { id: hideTimer; interval: 2500; onTriggered: root.controlsVisible = false }
    onPlayingChanged: if (playing) hideTimer.restart()

    Shortcut { sequences: ["Space", "K", "Media Play"]; onActivated: root.togglePlay() }
    Shortcut { sequences: ["Left", "J"]; onActivated: root.seek(-10000) }
    Shortcut { sequences: ["Right", "L"]; onActivated: root.seek(30000) }
    Shortcut { sequence: "Up"; onActivated: { settings.volume = Math.min(1, settings.volume + 0.05); root.poke() } }
    Shortcut { sequence: "Down"; onActivated: { settings.volume = Math.max(0, settings.volume - 0.05); root.poke() } }
    Shortcut { sequence: "M"; onActivated: settings.muted = !settings.muted }
    Shortcut { sequences: ["F", "F11"]; onActivated: root.toggleFullscreen() }
    Shortcut { sequence: "Escape"; onActivated: root.fullscreen ? root.toggleFullscreen() : root.close() }
    Shortcut { sequences: ["PgDown", "Media Next"]; onActivated: playlist.next() }
    Shortcut { sequences: ["PgUp", "Media Previous"]; onActivated: playlist.previous() }
    Shortcut { sequence: "Ctrl+O"; onActivated: fileDialog.open() }

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        titleDelegate: Item {}
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
        background: Rectangle { color: "black" }

        Item {
            anchors.fill: parent

            VideoOutput {
                id: video
                anchors.fill: parent
                visible: !playlist.isAudio
            }

            // ---------------- Musik: Cover und Titel
            Rectangle {
                anchors.fill: parent
                visible: playlist.isAudio
                color: Kirigami.Theme.backgroundColor
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit * 2
                    anchors.bottomMargin: bar.height + Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.gridUnit * 2
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Image {
                                id: cover
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height); height: width
                                fillMode: Image.PreserveAspectFit
                                source: {
                                    const img = player.metaData.value(MediaMetaData.CoverArtImage) || player.metaData.value(MediaMetaData.ThumbnailImage)
                                    return img ? img : ""
                                }
                                visible: status === Image.Ready
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: !cover.visible
                                source: "audio-x-generic"
                                width: Math.min(parent.width, parent.height, Kirigami.Units.gridUnit * 10); height: width
                                opacity: 0.5
                            }
                        }
                        Kirigami.Heading {
                            text: player.metaData.stringValue(MediaMetaData.Title) || playlist.title
                            level: 1
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        QQC2.Label {
                            text: [player.metaData.stringValue(MediaMetaData.ContributingArtist) || player.metaData.stringValue(MediaMetaData.AlbumArtist),
                                   player.metaData.stringValue(MediaMetaData.AlbumTitle)].filter(s => s).join(" · ")
                            opacity: 0.7
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                    // Titel im Ordner
                    QQC2.ScrollView {
                        visible: playlist.count > 1 && root.width > Kirigami.Units.gridUnit * 36
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                        Layout.fillHeight: true
                        ListView {
                            model: playlist.titles
                            currentIndex: playlist.index
                            clip: true
                            delegate: QQC2.ItemDelegate {
                                required property string modelData
                                required property int index
                                width: ListView.view.width
                                text: (index + 1) + ".  " + modelData
                                highlighted: index === playlist.index
                                onClicked: playlist.go(index)
                            }
                        }
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: playlist.count === 0
                icon.name: "multimedia-player"
                text: "Video oder Musik öffnen"
                explanation: "Datei hierher ziehen oder Strg+O drücken"
                helpfulAction: Kirigami.Action { text: "Datei öffnen …"; icon.name: "document-open"; onTriggered: fileDialog.open() }
            }

            // Mausbewegung zeigt die Steuerleiste; Klick = Pause, Doppelklick = Vollbild (wie Windows)
            MouseArea {
                anchors.fill: parent
                anchors.bottomMargin: root.showControls ? bar.height : 0
                hoverEnabled: true
                cursorShape: root.showControls ? Qt.ArrowCursor : Qt.BlankCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: root.poke()
                onClicked: (m) => { if (m.button === Qt.RightButton) moreMenu.popup(); else if (!playlist.isAudio && playlist.count) clickTimer.restart() }
                onDoubleClicked: { clickTimer.stop(); root.toggleFullscreen() }
                onWheel: (w) => { settings.volume = Math.max(0, Math.min(1, settings.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))); root.poke() }
                Timer { id: clickTimer; interval: 250; onTriggered: root.togglePlay() }
            }

            DropArea {
                anchors.fill: parent
                onDropped: (drop) => { if (drop.hasUrls) playlist.openUrls(drop.urls) }
            }

            // ---------------- Steuerleiste
            QQC2.Control {
                id: bar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                opacity: root.showControls ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                hoverEnabled: true
                padding: Kirigami.Units.largeSpacing
                Kirigami.Theme.colorSet: Kirigami.Theme.Window
                Kirigami.Theme.inherit: false
                background: Rectangle { color: Kirigami.Theme.backgroundColor; opacity: playlist.isAudio ? 1 : 0.92 }

                contentItem: ColumnLayout {
                    spacing: 0
                    RowLayout {
                        QQC2.Label { text: playlist.time(player.position); font: Kirigami.Theme.smallFont }
                        QQC2.Slider {
                            id: seekBar
                            Layout.fillWidth: true
                            from: 0
                            to: Math.max(1, player.duration)
                            value: pressed ? value : player.position
                            enabled: player.seekable
                            onMoved: player.position = value
                        }
                        QQC2.Label { text: playlist.time(player.duration); font: Kirigami.Theme.smallFont }
                    }
                    RowLayout {
                        QQC2.Label {
                            text: playlist.title
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                        }
                        Tool { icon.name: "media-skip-backward"; text: "Vorheriger Titel"; enabled: playlist.index > 0; onClicked: playlist.previous() }
                        Tool { icon.name: "media-seek-backward"; text: "10 Sekunden zurück (←)"; onClicked: root.seek(-10000) }
                        QQC2.RoundButton {
                            icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                            icon.width: Kirigami.Units.iconSizes.medium
                            icon.height: Kirigami.Units.iconSizes.medium
                            onClicked: root.togglePlay()
                            enabled: playlist.count > 0
                            QQC2.ToolTip.text: root.playing ? "Anhalten (Leertaste)" : "Wiedergeben (Leertaste)"
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                        Tool { icon.name: "media-seek-forward"; text: "30 Sekunden vor (→)"; onClicked: root.seek(30000) }
                        Tool { icon.name: "media-skip-forward"; text: "Nächster Titel"; enabled: playlist.index + 1 < playlist.count; onClicked: playlist.next() }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Item { Layout.fillWidth: true }
                            Tool {
                                icon.name: settings.muted || settings.volume === 0 ? "audio-volume-muted"
                                         : settings.volume < 0.4 ? "audio-volume-low" : settings.volume < 0.75 ? "audio-volume-medium" : "audio-volume-high"
                                text: settings.muted ? "Ton an (M)" : "Stumm (M)"
                                onClicked: settings.muted = !settings.muted
                            }
                            QQC2.Slider {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                                from: 0; to: 1
                                value: settings.volume
                                onMoved: { settings.volume = value; settings.muted = false }
                            }
                            Tool { icon.name: "overflow-menu"; text: "Weitere Optionen"; onClicked: moreMenu.popup() }
                            Tool {
                                visible: !playlist.isAudio
                                icon.name: root.fullscreen ? "view-restore" : "view-fullscreen"
                                text: root.fullscreen ? "Vollbild beenden (Esc)" : "Vollbild (F11)"
                                onClicked: root.toggleFullscreen()
                            }
                        }
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

    QQC2.Menu {
        id: moreMenu
        QQC2.MenuItem { text: "Datei öffnen …"; icon.name: "document-open"; onTriggered: fileDialog.open() }
        QQC2.Menu {
            title: "Geschwindigkeit"
            Repeater {
                model: [0.5, 0.75, 1, 1.25, 1.5, 2]
                delegate: QQC2.MenuItem {
                    required property real modelData
                    text: modelData === 1 ? "Normal" : String(modelData).replace(".", ",") + "×"
                    checkable: true
                    checked: Math.abs(player.playbackRate - modelData) < 0.01
                    onTriggered: player.playbackRate = modelData
                }
            }
        }
        QQC2.Menu {
            title: "Untertitel"
            enabled: player.subtitleTracks.length > 0
            QQC2.MenuItem { text: "Aus"; checkable: true; checked: player.activeSubtitleTrack < 0; onTriggered: player.activeSubtitleTrack = -1 }
            Repeater {
                model: player.subtitleTracks
                delegate: QQC2.MenuItem {
                    required property var modelData
                    required property int index
                    text: modelData.stringValue(MediaMetaData.Title) || modelData.stringValue(MediaMetaData.Language) || ("Spur " + (index + 1))
                    checkable: true
                    checked: player.activeSubtitleTrack === index
                    onTriggered: player.activeSubtitleTrack = index
                }
            }
        }
        QQC2.Menu {
            title: "Tonspur"
            enabled: player.audioTracks.length > 1
            Repeater {
                model: player.audioTracks
                delegate: QQC2.MenuItem {
                    required property var modelData
                    required property int index
                    text: modelData.stringValue(MediaMetaData.Title) || modelData.stringValue(MediaMetaData.Language) || ("Spur " + (index + 1))
                    checkable: true
                    checked: player.activeAudioTrack === index
                    onTriggered: player.activeAudioTrack = index
                }
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: root.fullscreen ? "Vollbild beenden" : "Vollbild"
            icon.name: "view-fullscreen"
            visible: !playlist.isAudio
            onTriggered: root.toggleFullscreen()
        }
    }

    // Dateiauswahl wie überall in Plasma
    Dialogs.FileDialog {
        id: fileDialog
        title: "Video oder Musik öffnen"
        currentFolder: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
        nameFilters: ["Videos und Musik (*.mp4 *.mkv *.webm *.avi *.mov *.m4v *.mpg *.mpeg *.wmv *.flv *.ts *.mp3 *.flac *.ogg *.opus *.wav *.m4a *.aac *.wma)",
                      "Alle Dateien (*)"]
        onAccepted: playlist.openUrls([selectedFile])
    }
}
