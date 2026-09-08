import QtQuick
import "../core"
import "../services"

Item {
    id: root

    property url source: IdentityService.personalImageSource
    property color accent: Theme.primary
    property bool active: false
    readonly property bool custom: source.toString().length > 0
    readonly property real ringSize: Math.max(10, Math.min(width, height) * 0.75)
    readonly property real orbitSize: Math.max(4, ringSize / 3)

    implicitWidth: 16
    implicitHeight: 16

    Image {
        anchors.fill: parent
        source: root.source
        visible: root.custom
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Item {
        anchors.fill: parent
        visible: !root.custom

        Rectangle {
            anchors.centerIn: parent
            width: root.ringSize
            height: root.ringSize
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: root.accent
        }

        Rectangle {
            anchors.centerIn: parent
            width: 3
            height: 3
            radius: width / 2
            visible: root.active
            color: Theme.tertiary
        }

        Rectangle {
            x: (root.width + root.ringSize) / 2 - root.orbitSize
            y: (root.height - root.ringSize) / 2 - root.orbitSize / 4
            width: root.orbitSize
            height: root.orbitSize
            radius: width / 2
            color: root.accent
            border.width: 1
            border.color: Theme.surfaceContainer
        }
    }
}
