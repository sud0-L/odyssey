import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root
    property var monitor
    property real requestedItemSpacing: Config.island.hoverItemSpacing
    readonly property real edgePadding: Config.island.hoverEdgePadding
    readonly property var visibleOrder: Config.island.hoverItemOrder.filter(itemId =>
        itemId === "Media" ? MediaService.hoverVisible
        : itemId === "Network" ? NetworkService.available
        : itemId === "Bluetooth" ? BluetoothService.available
        : itemId === "Battery" ? BatteryService.available : true)
    readonly property int visibleItemCount: visibleOrder.length
    // The width control sets the baseline at the default 8 px spacing.
    // The bar follows the chosen gap and outer padding independently.
    implicitWidth: Math.round(Math.max(
        contentRow.implicitWidth + edgePadding * 2,
        Config.island.hoverWidth + (requestedItemSpacing - 8)
            * Math.max(0, visibleItemCount - 1)
            + (edgePadding - Theme.space5) * 2))

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: root.edgePadding
        anchors.rightMargin: root.edgePadding
        spacing: root.requestedItemSpacing

        Repeater {
            model: Config.island.hoverItemOrder
            delegate: Item {
                required property string modelData
                readonly property bool edgeItem: modelData === root.visibleOrder[0]
                    || modelData === root.visibleOrder[root.visibleItemCount - 1]
                Layout.preferredWidth: Math.max(hoverItem.implicitWidth,
                    hoverItem.minimumWidth)
                Layout.minimumWidth: hoverItem.minimumWidth
                Layout.maximumWidth: edgeItem ? Layout.preferredWidth
                    : Number.POSITIVE_INFINITY
                Layout.fillWidth: !edgeItem
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
    }
}
