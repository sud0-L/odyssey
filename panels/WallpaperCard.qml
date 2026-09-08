import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    required property var wallpaper
    property bool current: false
    property bool applying: false
    property string currentLabel: "ACTIVE"
    signal activated(string path)

    radius: Theme.radiusMedium
    clip: true
    color: Theme.surfaceContainerHigh
    border.width: current ? 2 : 1
    border.color: current ? Theme.primary
        : cardHover.hovered ? Qt.alpha(Theme.primary, 0.56)
        : Qt.alpha(Theme.outlineVariant, 0.42)
    scale: cardTap.pressed ? 0.985 : 1

    Image {
        anchors.fill: parent
        source: root.wallpaper.source
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 420
        sourceSize.height: 250
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        color: Qt.alpha(Theme.surface, Theme.dark ? 0.86 : 0.78)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space2
            anchors.rightMargin: Theme.space2
            spacing: Theme.space1

            Text {
                Layout.fillWidth: true
                text: root.wallpaper.name
                color: Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            Text {
                visible: root.current || root.applying
                text: root.applying ? "󰔟" : "󰄬"
                color: root.applying ? Theme.tertiary : Theme.primary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        visible: root.current
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.space2
        width: 44
        height: 18
        radius: 9
        color: Theme.primary

        Text {
            anchors.centerIn: parent
            text: root.currentLabel
            color: Theme.primaryText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 7
            font.weight: Font.Bold
        }
    }

    HoverHandler { id: cardHover }
    TapHandler {
        id: cardTap
        enabled: !root.applying
        onTapped: root.activated(root.wallpaper.path)
    }

    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
    Behavior on scale { NumberAnimation { duration: Animations.fast } }
}
