import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

Item {
    id: root

    function formatPosition(seconds): string {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00"
        const minutes = Math.floor(seconds / 60)
        const remainder = Math.floor(seconds % 60)
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    RowLayout {
        anchors.fill: parent
        visible: MediaService.available
        spacing: Theme.space4

        ClippingRectangle {
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Theme.surfaceContainerHigh

            Image {
                id: artworkImage
                anchors.fill: parent
                source: MediaService.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                visible: !artworkImage.visible
                color: Qt.alpha(Theme.primaryContainer, Theme.dark ? 0.34 : 0.52)
                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 56
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 46
                color: Qt.alpha(Theme.surface, 0.82)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space3
                    Text {
                        Layout.fillWidth: true
                        text: MediaService.identity
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: MediaService.playerCount > 1
                        text: "󰒭  Next player"
                        color: playerHover.hovered ? Theme.primary
                            : Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 8
                        HoverHandler { id: playerHover }
                        TapHandler { onTapped: MediaService.selectNextPlayer() }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space3

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: MediaService.title
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.family: Config.appearance.fontFamily
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: MediaService.artist
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: MediaService.album
                color: Qt.alpha(Theme.surfaceVariantText, 0.72)
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }

            Item { Layout.preferredHeight: Theme.space2 }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12

                LevelTrack {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    value: MediaService.progress
                    accent: Theme.primary
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
                    font.pixelSize: 8
                }
                Text {
                    text: root.formatPosition(MediaService.duration)
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 8
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.space4

                Repeater {
                    model: [
                        { icon: "󰒮", action: "previous", available: MediaService.canPrevious },
                        { icon: MediaService.playing ? "󰏤" : "󰐊",
                            action: "toggle", available: MediaService.canToggle },
                        { icon: "󰒭", action: "next", available: MediaService.canNext }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool primary: modelData.action === "toggle"
                        Layout.preferredWidth: primary ? 52 : 40
                        Layout.preferredHeight: primary ? 52 : 40
                        radius: width / 2
                        opacity: modelData.available ? 1 : 0.36
                        color: primary ? Theme.primary
                            : mediaHover.hovered ? Theme.surfaceContainerHigh
                            : Qt.alpha(Theme.surfaceContainerHigh, 0.64)
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: primary ? Theme.primaryText : Theme.surfaceText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: primary ? 22 : 17
                        }
                        HoverHandler { id: mediaHover; enabled: modelData.available }
                        TapHandler {
                            enabled: modelData.available
                            onTapped: {
                                if (modelData.action === "previous") MediaService.previous()
                                else if (modelData.action === "next") MediaService.next()
                                else MediaService.togglePlaying()
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !MediaService.available
        spacing: Theme.space3

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            radius: 42
            color: Qt.alpha(Theme.primaryContainer, 0.36)
            Text {
                anchors.centerIn: parent
                text: "󰝚"
                color: Theme.primary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 36
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing playing"
            color: Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textTitle
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Media controls will appear when an MPRIS player is active."
            color: Theme.surfaceVariantText
            font.family: Config.appearance.fontFamily
            font.pixelSize: 10
        }
    }
}
