import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

Item {
    id: root

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space5
        anchors.topMargin: Theme.space2
        anchors.bottomMargin: Theme.space2
        spacing: Theme.space3

        ClippingRectangle {
            Layout.preferredWidth: 68
            Layout.preferredHeight: 68
            radius: Theme.radiusLarge
            color: Theme.surfaceContainerHigh

            Image {
                id: islandArtwork
                anchors.fill: parent
                source: MediaService.artwork
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            OdysseyMark {
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: !islandArtwork.visible
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            Text {
                Layout.fillWidth: true
                text: MediaService.title
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: MediaService.artist
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textSmall
            }

            LevelTrack {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space1
                value: MediaService.progress
                accent: Theme.tertiary
            }
        }

    }
}
