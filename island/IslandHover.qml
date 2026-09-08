import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root
    property var monitor
    property real requestedItemSpacing: Config.island.hoverItemSpacing
    readonly property real minimumContentWidth: Math.round(412
        * Config.island.hoverContentScale)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        spacing: Math.min(root.requestedItemSpacing, Math.max(0,
            (width - root.minimumContentWidth) / 8))

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        Repeater {
            model: Config.island.hoverItemOrder
            delegate: Item {
                required property string modelData
                Layout.preferredWidth: hoverItem.implicitWidth
                Layout.minimumWidth: hoverItem.minimumWidth
                Layout.maximumWidth: hoverItem.implicitWidth
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: hoverItem.available

                IslandHoverItem {
                    id: hoverItem
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width)
                    height: parent.height
                    itemId: modelData
                    monitor: root.monitor
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
    }
}
