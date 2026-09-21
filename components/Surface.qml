import QtQuick
import "../core"

Rectangle {
    id: root

    property color solidColor: Qt.alpha(Theme.surfaceContainer,
        Config.appearance.surfaceOpacity)
    property color solidBorderColor: Qt.alpha(Theme.outlineVariant,
        Theme.dark ? 0.62 : 0.48)

    color: SurfaceMaterial.fill(solidColor)
    border.color: SurfaceMaterial.outline(solidBorderColor)
    border.width: 1
    radius: Theme.radiusLarge

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, root.border.width)
        visible: SurfaceMaterial.glass && root.border.width > 0
        color: "transparent"
        radius: Math.max(0, root.radius - anchors.margins)
        border.width: 1
        border.color: SurfaceMaterial.innerHighlight
        opacity: SurfaceMaterial.glass ? 1 : 0
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius * 0.55
        anchors.rightMargin: root.radius * 0.55
        height: 1
        visible: SurfaceMaterial.glass
        color: SurfaceMaterial.depthEdge
    }

    Behavior on color { ColorAnimation { duration: Animations.normal } }
    Behavior on border.color { ColorAnimation { duration: Animations.normal } }
}
