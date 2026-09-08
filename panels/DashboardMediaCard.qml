import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

DashboardCard {
    id: root

    signal pageRequested()

    accent: Theme.primary
    onActivated: root.pageRequested()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space3

        ClippingRectangle {
            Layout.preferredWidth: 112
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.primaryContainer, 0.46)

            Image {
                id: dashboardArtwork
                anchors.fill: parent
                source: MediaService.artwork
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: MediaService.available && status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: !dashboardArtwork.visible
                text: MediaService.available ? "󰝚" : "󰎆"
                color: Theme.primary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 36
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "NOW PLAYING"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 8
                    font.letterSpacing: 1
                }
                Text {
                    text: "Media  ›"
                    color: Theme.primary
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 8
                }
            }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: MediaService.available ? MediaService.title : "Nothing playing"
                color: Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: MediaService.available
                    ? MediaService.artist : "Playback will appear here"
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
            LevelTrack {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                value: MediaService.progress
                accent: Theme.primary
            }
            Item { Layout.fillHeight: true }
        }
    }
}
