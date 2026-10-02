import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

Item {
    id: root

    readonly property bool hasArt: MediaService.available
        && MediaService.artwork.toString().length > 0
    readonly property bool compact: width < 520 || height < 320
    readonly property color detailAccent: Theme.tertiary
    readonly property string trackKey: MediaService.available
        ? MediaService.identity + "\n" + MediaService.title + "\n"
            + MediaService.artist + "\n" + MediaService.album : ""
    property string shownTitle: MediaService.title
    property string shownArtist: MediaService.artist
    property string shownAlbum: MediaService.album
    property real metadataOpacity: 1
    onTrackKeyChanged: metadataTransition.restart()

    SequentialAnimation {
        id: metadataTransition
        NumberAnimation {
            target: root; property: "metadataOpacity"
            to: 0; duration: Animations.fast / 2
        }
        ScriptAction { script: {
            root.shownTitle = MediaService.title
            root.shownArtist = MediaService.artist
            root.shownAlbum = MediaService.album
        } }
        NumberAnimation {
            target: root; property: "metadataOpacity"
            to: 1; duration: Animations.normal
        }
    }

    function formatPosition(seconds): string {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00"
        const minutes = Math.floor(seconds / 60)
        const remainder = Math.floor(seconds % 60)
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    Item {
        anchors.fill: parent

        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: SurfaceMaterial.fill(Theme.surfaceContainer)
            border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
            border.color: SurfaceMaterial.outline(Qt.alpha(Theme.outlineVariant, 0.5))

            MediaBackdrop {
                anchors.fill: parent
                artworkSource: MediaService.artwork
                active: root.visible && root.hasArt
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? Theme.space3 : Theme.space5
            spacing: root.compact ? Theme.space2 : Theme.space3
            visible: MediaService.available

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Text {
                    visible: MediaService.playerCount > 1
                    text: "󰒭"
                    color: nextPlayerHover.hovered ? Theme.primary : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(16, true)
                    HoverHandler { id: nextPlayerHover }
                    TapHandler { onTapped: MediaService.selectNextPlayer() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.compact ? Theme.space3 : Theme.space5

                ClippingRectangle {
                    Layout.preferredWidth: Math.min(root.compact ? 148 : 230,
                        Math.max(105, root.width * 0.37))
                    Layout.preferredHeight: Math.min(width,
                        Math.max(105, root.height - 98))
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusLarge
                    color: Qt.alpha(Theme.primaryContainer, 0.42)
                    border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
                    border.color: Qt.alpha(Theme.outlineVariant, 0.64)

                    MediaArtwork {
                        id: coverArtwork
                        anchors.fill: parent
                        artworkSource: MediaService.artwork
                        active: root.visible && root.hasArt
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !coverArtwork.ready
                        text: "󰝚"
                        color: Theme.primary
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(56, true)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.compact ? Theme.space1 : Theme.space2

                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: root.shownTitle
                        opacity: root.metadataOpacity
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(
                            root.compact ? 19 : 27, false)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.shownArtist
                        opacity: root.metadataOpacity
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(
                            root.compact ? 11 : 14, false)
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.shownAlbum
                        opacity: root.metadataOpacity
                        color: Qt.alpha(Theme.surfaceVariantText, 0.84)
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(10, false)
                    }

                    Item { Layout.preferredHeight: Theme.space2 }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        LevelTrack {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 5
                            value: MediaService.progress
                            accent: root.hasArt ? root.detailAccent : Theme.primary
                        }
                        TapHandler {
                            enabled: MediaService.canSeek
                            onTapped: eventPoint => MediaService.seekTo(
                                eventPoint.position.x / parent.width)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.formatPosition(MediaService.position)
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: Config.island.expandedPixelSize(9, false)
                        }
                        Text {
                            text: root.formatPosition(MediaService.duration)
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: Config.island.expandedPixelSize(9, false)
                        }
                    }
                    MediaTransport {
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Item {
                Layout.preferredWidth: Math.min(320,
                    Math.max(220, root.width * 0.44))
                Layout.preferredHeight: 36
                visible: AudioService.available && !root.compact

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space2
                    Text {
                        text: AudioService.muted ? "󰝟" : "󰕾"
                        color: AudioService.muted ? Theme.surfaceVariantText
                            : Theme.primary
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(16, true)
                        MouseArea {
                            anchors.fill: parent
                            onClicked: AudioService.toggleMute()
                        }
                    }
                    Item {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 18
                        LevelTrack {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            value: AudioService.volume
                            accent: Theme.primary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => AudioService.setVolume(
                                Math.round(mouse.x / parent.width * 100))
                        }
                    }
                    Text {
                        text: AudioService.muted ? "MUTE"
                            : AudioService.volumePercent + "%"
                        color: Theme.surfaceText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: AudioService.outputName
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.space5 * 2, 360)
            visible: !MediaService.available
            spacing: Theme.space3
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
                radius: 42
                color: Qt.alpha(Theme.primaryContainer, 0.38)
                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(36, true)
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing playing"
                color: Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(Theme.textTitle, false)
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: "Media controls will appear when an MPRIS player is active."
                color: Theme.surfaceVariantText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(10, false)
            }
        }
    }
}
