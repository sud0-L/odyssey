import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

DashboardCard {
    id: root

    signal pageRequested()

    readonly property bool hasArt: MediaService.available
        && MediaService.artwork.toString().length > 0
    readonly property color detailAccent: Theme.tertiary
    readonly property string trackKey: MediaService.available
        ? MediaService.identity + "\n" + MediaService.title + "\n"
            + MediaService.artist + "\n" + MediaService.album : ""
    property string shownTitle: MediaService.available ? MediaService.title : "Nothing playing"
    property string shownArtist: MediaService.available ? MediaService.artist
        : "Playback will appear here"
    property string shownAlbum: MediaService.available
        ? (MediaService.album || MediaService.identity) : ""
    property real metadataOpacity: 1
    accent: Theme.primary
    interactive: false
    color: SurfaceMaterial.fill(Theme.surfaceContainerHigh)
    border.color: SurfaceMaterial.outline(Qt.alpha(Theme.outlineVariant, 0.5))
    onTrackKeyChanged: metadataTransition.restart()

    SequentialAnimation {
        id: metadataTransition
        NumberAnimation {
            target: root; property: "metadataOpacity"
            to: 0; duration: Animations.fast / 2
        }
        ScriptAction { script: {
            root.shownTitle = MediaService.available ? MediaService.title : "Nothing playing"
            root.shownArtist = MediaService.available ? MediaService.artist
                : "Playback will appear here"
            root.shownAlbum = MediaService.available
                ? (MediaService.album || MediaService.identity) : ""
        } }
        NumberAnimation {
            target: root; property: "metadataOpacity"
            to: 1; duration: Animations.normal
        }
    }

    HoverHandler { id: mediaHover }

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
            anchors.margins: 1
            radius: Math.max(0, root.radius - 1)
            color: SurfaceMaterial.fill(Theme.surfaceContainer)

            MediaBackdrop {
                anchors.fill: parent
                artworkSource: MediaService.artwork
                active: root.visible && root.hasArt
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.pageRequested()
        }

        RowLayout {
            id: mediaRow
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space3

            ClippingRectangle {
                Layout.preferredWidth: Math.min(118, Math.max(76, root.width * 0.26))
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Qt.alpha(Theme.primaryContainer, 0.5)
                border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
                border.color: Qt.alpha(Theme.outlineVariant, 0.55)

                MediaArtwork {
                    id: coverArtwork
                    anchors.fill: parent
                    artworkSource: MediaService.artwork
                    active: root.visible && root.hasArt
                }
                Text {
                    anchors.centerIn: parent
                    visible: !coverArtwork.ready
                    text: MediaService.available ? "󰝚" : "󰎆"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(36, true)
                }
            }

            ColumnLayout {
                id: infoColumn
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space1

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Media  ›"
                        color: root.hasArt ? root.detailAccent : Theme.primary
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                }
                Item { Layout.fillHeight: true }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space1
                    opacity: root.metadataOpacity
                    Text {
                        Layout.fillWidth: true
                        text: root.shownTitle
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(19, false)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.shownArtist
                        color: Qt.alpha(Theme.surfaceText, 0.88)
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(12, false)
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: MediaService.available && text.length > 0
                        text: root.shownAlbum
                        color: Qt.alpha(Theme.surfaceText, 0.72)
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(10, false)
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: MediaService.available && MediaService.duration > 0
                        text: root.formatPosition(MediaService.position) + " / "
                            + root.formatPosition(MediaService.duration)
                        color: Qt.alpha(Theme.surfaceText, 0.72)
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(10, false)
                    }
                }
                Item { Layout.fillHeight: true }
                LevelTrack {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    value: MediaService.progress
                    accent: root.hasArt ? root.detailAccent : Theme.primary
                }
                Item {
                    Layout.preferredHeight: MediaService.available ? 56 : 0
                }
            }
        }

        MediaTransport {
            x: mediaRow.x + infoColumn.x + (infoColumn.width - width) / 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space3 + 10
            visible: MediaService.available && (mediaHover.hovered || opacity > 0)
            opacity: mediaHover.hovered && MediaService.available ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Animations.fast } }
        }
    }
}
