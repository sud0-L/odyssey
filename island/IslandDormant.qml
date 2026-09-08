import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root
    signal powerRequested()
    signal captureRequested()
    property bool powerHovered: false
    readonly property var displayOrder: CaptureService.recording
            && Config.island.restItemOrder.indexOf("PowerProfile") < 0
        ? Config.island.restItemOrder.concat(["PowerProfile"])
        : Config.island.restItemOrder
    readonly property var leftDisplayOrder: displayOrder.slice(0,
        Math.ceil(displayOrder.length / 2))
    readonly property var rightDisplayOrder: displayOrder.slice(
        Math.ceil(displayOrder.length / 2))

    RowLayout {
        anchors.right: restClock.left
        anchors.rightMargin: Config.island.restItemSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.island.restItemSpacing

        Repeater {
            model: root.leftDisplayOrder
            delegate: IslandRestItem {
                required property string modelData
                itemId: modelData
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                onPowerHoveredChanged: if (itemId === "PowerProfile")
                    root.powerHovered = powerHovered
                onPowerRequested: root.powerRequested()
                onCaptureRequested: root.captureRequested()
            }
        }
    }

    IslandRestItem {
        id: restClock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        itemId: "Clock"
    }

    RowLayout {
        anchors.left: restClock.right
        anchors.leftMargin: Config.island.restItemSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.island.restItemSpacing

        Repeater {
            model: root.rightDisplayOrder
            delegate: IslandRestItem {
                required property string modelData
                itemId: modelData
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                onPowerHoveredChanged: if (itemId === "PowerProfile")
                    root.powerHovered = powerHovered
                onPowerRequested: root.powerRequested()
                onCaptureRequested: root.captureRequested()
            }
        }
    }
}
