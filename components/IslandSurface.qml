import QtQuick
import QtQuick.Shapes
import "../core"

Item {
    id: root

    property real bodyWidth: 200
    property bool attached: false
    property real radius: Theme.radiusLarge
    property color fillColor: Qt.alpha(Theme.surfaceContainer,
        Config.appearance.surfaceOpacity)
    property color outlineColor: Qt.alpha(Theme.outlineVariant,
        Theme.dark ? 0.62 : 0.48)
    property real outlineWidth: 1
    readonly property real shoulderWidth: attached
        ? Math.min(22, Math.max(12, height * 0.46)) : 0
    readonly property real bottomRadius: Math.min(radius, height / 2,
        bodyWidth / 2)

    width: bodyWidth + shoulderWidth * 2
    clip: true

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.bodyWidth
        height: parent.height
        visible: !root.attached
        color: root.fillColor
        border.color: root.outlineColor
        border.width: root.outlineWidth
        radius: root.radius
    }

    Shape {
        id: attachedShape
        anchors.fill: parent
        visible: root.attached
        antialiasing: true

        ShapePath {
            strokeColor: root.outlineWidth > 0
                ? root.outlineColor : "transparent"
            strokeWidth: root.outlineWidth
            fillColor: root.fillColor
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: 0
            startY: -root.outlineWidth

            PathLine {
                x: attachedShape.width
                y: -root.outlineWidth
            }
            PathCubic {
                x: attachedShape.width - root.shoulderWidth
                y: root.shoulderWidth
                control1X: attachedShape.width - root.shoulderWidth * 0.35
                control1Y: -root.outlineWidth
                control2X: attachedShape.width - root.shoulderWidth
                control2Y: root.shoulderWidth * 0.35
            }
            PathLine {
                x: attachedShape.width - root.shoulderWidth
                y: attachedShape.height - root.bottomRadius
            }
            PathQuad {
                x: attachedShape.width - root.shoulderWidth - root.bottomRadius
                y: attachedShape.height
                controlX: attachedShape.width - root.shoulderWidth
                controlY: attachedShape.height
            }
            PathLine {
                x: root.shoulderWidth + root.bottomRadius
                y: attachedShape.height
            }
            PathQuad {
                x: root.shoulderWidth
                y: attachedShape.height - root.bottomRadius
                controlX: root.shoulderWidth
                controlY: attachedShape.height
            }
            PathLine {
                x: root.shoulderWidth
                y: root.shoulderWidth
            }
            PathCubic {
                x: 0
                y: -root.outlineWidth
                control1X: root.shoulderWidth
                control1Y: root.shoulderWidth * 0.35
                control2X: root.shoulderWidth * 0.35
                control2Y: -root.outlineWidth
            }
        }
    }

    Behavior on fillColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on outlineColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on radius {
        NumberAnimation {
            duration: Animations.normal
            easing.type: Animations.standardEase
        }
    }
}
