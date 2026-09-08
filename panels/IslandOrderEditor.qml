import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root
    property string context: "rest"
    readonly property var definitions: context === "rest" ? [
        { id: "Weather", icon: "󰖐", label: "Weather" },
        { id: "Dnd", icon: "󰂛", label: "DND" },
        { id: "KeepAwake", icon: "󰅶", label: "Awake" },
        { id: "PowerProfile", icon: "󰓅", label: "Power" }
    ] : [
        { id: "Workspaces", icon: "󰍹", label: "Spaces" },
        { id: "Clock", icon: "󰥔", label: "Clock" },
        { id: "Media", icon: "󰝚", label: "Media" },
        { id: "Audio", icon: "󰕾", label: "Audio" },
        { id: "Network", icon: "󰤨", label: "Network" },
        { id: "Dnd", icon: "󰂛", label: "DND" },
        { id: "Bluetooth", icon: "󰂯", label: "Bluetooth" },
        { id: "KeepAwake", icon: "󰅶", label: "Awake" },
        { id: "Battery", icon: "󰁹", label: "Battery" }
    ]
    readonly property var order: context === "rest"
        ? Config.island.restItemOrder : Config.island.hoverItemOrder
    implicitHeight: context === "rest" ? 177 : 216

    function definition(itemId): var {
        for (const candidate of definitions) {
            if (candidate.id === itemId)
                return candidate
        }
        return { id: itemId, icon: "•", label: itemId }
    }

    function place(itemId, targetIndex): void {
        const next = order.filter(candidate => candidate !== itemId)
        next.splice(Math.max(0, Math.min(targetIndex, next.length)), 0, itemId)
        SettingsStore.setIslandItemOrder(context, next)
    }

    function remove(itemId): void {
        SettingsStore.setIslandItemOrder(context,
            order.filter(candidate => candidate !== itemId))
    }

    function add(itemId): void {
        if (order.indexOf(itemId) < 0)
            SettingsStore.setIslandItemOrder(context, order.concat([itemId]))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Text {
            visible: context !== "rest"
            text: "ISLAND SLOTS"
            color: Theme.primary
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 1.1
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            spacing: Theme.space1

            Repeater {
                model: root.definitions.length
                delegate: DropArea {
                    id: slot
                    required property int index
                    readonly property string currentId:
                        index < root.order.length ? root.order[index] : ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    keys: ["odyssey-island-item"]
                    onDropped: drop => {
                        if (drop.source?.itemId)
                            root.place(drop.source.itemId, index)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: slot.containsDrag
                            ? Qt.alpha(Theme.primaryContainer, 0.78)
                            : Qt.alpha(Theme.surfaceContainerLow, 0.66)
                        border.width: 1
                        border.color: slot.containsDrag ? Theme.primary
                            : Qt.alpha(Theme.outlineVariant, 0.48)
                        Text {
                            anchors.centerIn: parent
                            visible: slot.currentId.length === 0
                            text: (slot.index + 1).toString()
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: 9
                        }
                    }

                    DragTile {
                        x: 0
                        y: 0
                        width: parent.width
                        height: parent.height
                        visible: slot.currentId.length > 0
                        itemId: slot.currentId
                        icon: root.definition(itemId).icon
                        label: root.definition(itemId).label
                        onClicked: root.remove(itemId)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "AVAILABLE ITEMS"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.1
            }
            Text {
                text: "Drag into a slot · click to add/remove"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            spacing: Theme.space1
            Repeater {
                model: root.definitions
                delegate: DragTile {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    visible: root.order.indexOf(modelData.id) < 0
                    itemId: modelData.id
                    icon: modelData.icon
                    label: modelData.label
                    onClicked: root.add(itemId)
                }
            }
            Item {
                visible: root.order.length === root.definitions.length
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Text {
                    anchors.centerIn: parent
                    text: "All items are in the Island"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        DropArea {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            keys: ["odyssey-island-item"]
            onDropped: drop => {
                if (drop.source?.itemId)
                    root.remove(drop.source.itemId)
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: parent.containsDrag ? Qt.alpha(Theme.error, 0.16)
                    : "transparent"
                border.width: 1
                border.color: parent.containsDrag ? Theme.error
                    : Qt.alpha(Theme.outlineVariant, 0.4)
                Text {
                    anchors.centerIn: parent
                    text: "Drag here to remove from this phase"
                    color: parent.parent.containsDrag ? Theme.error
                        : Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                }
            }
        }
    }

    component DragTile: Rectangle {
        id: tile
        required property string itemId
        property string icon: ""
        property string label: ""
        property real dragOriginX: 0
        property real dragOriginY: 0
        signal clicked()
        activeFocusOnTab: true
        implicitWidth: 56
        implicitHeight: 52
        radius: Theme.radiusSmall
        color: tileDrag.drag.active ? Theme.primaryContainer
            : tileHover.hovered ? Theme.surfaceContainerHigh
            : Qt.alpha(Theme.surfaceContainer, 0.9)
        border.width: 1
        border.color: activeFocus ? Theme.primary
            : tileDrag.drag.active ? Theme.primary
            : Qt.alpha(Theme.outlineVariant, 0.54)
        z: tileDrag.drag.active ? 100 : 1

        Drag.active: tileDrag.drag.active
        Drag.source: tile
        Drag.keys: ["odyssey-island-item"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.icon
                color: tileDrag.drag.active ? Theme.primaryContainerText
                    : Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.label
                color: tileDrag.drag.active ? Theme.primaryContainerText
                    : Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 8
            }
        }
        HoverHandler { id: tileHover }
        MouseArea {
            id: tileDrag
            anchors.fill: parent
            drag.target: tile
            onPressed: {
                tile.forceActiveFocus()
                tile.dragOriginX = tile.x
                tile.dragOriginY = tile.y
            }
            onClicked: tile.clicked()
            onReleased: {
                tile.x = tile.dragOriginX
                tile.y = tile.dragOriginY
            }
        }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }
}
