import QtQuick
import Quickshell.Widgets
import "../core"
import "../services"

Item {
    id: root

    property real imageMargin: 2
    readonly property bool hasImage: IdentityService.hasPersonalImage
    readonly property bool imageFailed:
        personalImage.status === Image.Error
    readonly property real logoDiameter: Math.max(18,
        Math.min(width, height) - imageMargin * 2)
    signal editRequested()

    implicitWidth: 150
    implicitHeight: 48

    ClippingRectangle {
        id: circle
        anchors.centerIn: parent
        width: root.logoDiameter
        height: width
        radius: width / 2
        color: logoHover.hovered
            ? Qt.alpha(Theme.surfaceContainerHigh, 0.82)
            : Qt.alpha(Theme.surfaceContainer, root.hasImage ? 0.18 : 0.48)
        border.width: 1
        border.color: logoHover.hovered
            ? Qt.alpha(Theme.primary, 0.72)
            : Qt.alpha(Theme.outlineVariant, root.hasImage ? 0.26 : 0.48)

        Image {
            id: personalImage
            anchors.fill: parent
            source: IdentityService.personalImageSource
            visible: root.hasImage && status !== Image.Error
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasImage || root.imageFailed
            text: root.imageFailed ? "󰏫" : "󰋩"
            color: Theme.primary
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Math.max(10, circle.width * 0.28)
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: root.hasImage && !root.imageFailed && logoHover.hovered
            color: Qt.alpha(Theme.surface, 0.62)

            Text {
                anchors.centerIn: parent
                text: "󰏫"
                color: Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.max(9, circle.width * 0.22)
            }
        }

        Behavior on color {
            ColorAnimation { duration: Animations.fast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Animations.fast }
        }
    }

    HoverHandler { id: logoHover }
    TapHandler { onTapped: root.editRequested() }
}
