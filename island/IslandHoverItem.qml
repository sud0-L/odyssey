import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../components"
import "../core"
import "../services"

Item {
    id: root
    required property string itemId
    property var monitor
    readonly property bool available: itemId === "Media" ? MediaService.hoverVisible
        : itemId === "Network" ? NetworkService.available
        : itemId === "Bluetooth" ? BluetoothService.available
        : itemId === "Battery" ? BatteryService.available : true
    implicitWidth: itemId === "Workspaces" ? Math.round(54 * Math.max(1,
            Config.island.hoverIconScale))
        : itemId === "Clock" ? Math.round(74 * Math.max(1,
            Config.island.hoverTextScale))
        : itemId === "Media" ? Math.round(90 * Math.max(1,
            Config.island.hoverTextScale))
        : itemId === "Audio" || itemId === "Network"
            ? Math.round(42 * Config.island.hoverContentScale)
        : itemId === "Battery" ? Math.round(48 * Config.island.hoverContentScale)
        : itemId === "Dnd" && NotificationService.count > 0
            ? Math.round(18 * Config.island.hoverContentScale)
        : Math.round(24 * Config.island.hoverContentScale)
    readonly property real minimumWidth: itemId === "Workspaces"
        ? Math.round(56 * Config.island.hoverIconScale)
        : itemId === "Clock"
            ? Math.round(72 * Config.island.hoverTextScale)
        : itemId === "Media"
            ? Math.round(94 * Config.island.hoverContentScale)
        : itemId === "Audio" || itemId === "Network"
            ? Math.round(38 * Config.island.hoverContentScale)
        : itemId === "Battery"
            ? Math.round(44 * Config.island.hoverContentScale)
        : itemId === "Dnd" && NotificationService.count > 0
            ? Math.round(18 * Config.island.hoverContentScale)
        : Math.round(22 * Config.island.hoverContentScale)
    implicitHeight: Config.island.hoverHeight
    visible: available

    Loader {
        anchors.fill: parent
        sourceComponent: root.itemId === "Workspaces" ? workspacesComponent
            : root.itemId === "Clock" ? clockComponent
            : root.itemId === "Media" ? mediaComponent
            : root.itemId === "Audio" ? audioComponent
            : root.itemId === "Network" ? networkComponent
            : root.itemId === "Dnd" ? dndComponent
            : root.itemId === "Bluetooth" ? bluetoothComponent
            : root.itemId === "KeepAwake" ? keepAwakeComponent
            : root.itemId === "Battery" ? batteryComponent : null
    }

    Component {
        id: workspacesComponent
        Item {
            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.space1
                Repeater {
                    model: 5
                    StatusDot {
                        active: root.monitor?.activeWorkspace?.id === index + 1
                        occupied: HyprlandService.occupiedWorkspaces.some(
                            workspace => workspace.id === index + 1)
                        urgent: HyprlandService.urgentWorkspaces.some(
                            workspace => workspace.id === index + 1)
                    }
                }
            }
        }
    }

    Component {
        id: clockComponent
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    text: ShellState.time
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Math.round(Theme.textBody
                        * Config.island.hoverTextScale)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: ShellState.dateLabel
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Math.round(Theme.textSmall
                        * Config.island.hoverTextScale)
                }
            }
        }
    }

    Component {
        id: mediaComponent
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: Theme.space2
                ClippingRectangle {
                    Layout.preferredWidth: Math.round(30
                        * Config.island.hoverIconScale)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Theme.radiusSmall
                    color: Theme.primaryContainer
                    Image {
                        id: artworkImage
                        anchors.fill: parent
                        source: MediaService.artwork
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: artworkImage.status !== Image.Ready
                        text: "󰎈"
                        color: Theme.primaryContainerText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Math.round(Theme.iconSmall
                            * Config.island.hoverIconScale)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: MediaService.title
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Math.round(Theme.textSmall
                            * Config.island.hoverTextScale)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: MediaService.artist
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Math.round(10
                            * Config.island.hoverTextScale)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Component {
        id: audioComponent
        CompactStatus {
            textScale: Config.island.hoverTextScale
            iconScale: Config.island.hoverIconScale
            icon: AudioService.muted ? "󰝟" : "󰕾"
            value: AudioService.available
                ? (AudioService.muted ? "OFF" : AudioService.volumePercent + "%") : "—"
            accent: AudioService.muted ? Theme.error : Theme.primary
        }
    }
    Component {
        id: networkComponent
        CompactStatus {
            textScale: Config.island.hoverTextScale
            iconScale: Config.island.hoverIconScale
            icon: NetworkService.icon
            value: NetworkService.wifiConnected ? NetworkService.signalPercent + "%"
                : (NetworkService.ethernetConnected ? "LAN" : "OFF")
            accent: NetworkService.connected ? Theme.primary : Theme.surfaceVariantText
        }
    }
    Component {
        id: dndComponent
        Item {
            Text {
                visible: NotificationService.count === 0
                anchors.centerIn: parent
                text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                color: NotificationService.doNotDisturb ? Theme.tertiary : Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.round(14 * Config.island.hoverIconScale)
            }
            Rectangle {
                visible: NotificationService.count > 0
                anchors.centerIn: parent
                width: 15; height: 15; radius: width / 2
                color: Theme.error
                Text { anchors.fill: parent; anchors.leftMargin: 1; text: NotificationService.count > 99 ? "99+" : NotificationService.count; color: Theme.foregroundFor(parent.color); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Config.appearance.monoFontFamily; font.pixelSize: 8; font.weight: Font.Bold }
            }
        }
    }
    Component {
        id: bluetoothComponent
        CompactStatus {
            textScale: Config.island.hoverTextScale
            iconScale: Config.island.hoverIconScale
            icon: BluetoothService.icon
            value: ""
            showValue: false
            accent: BluetoothService.connected ? Theme.primary
                : Theme.surfaceVariantText
        }
    }
    Component {
        id: keepAwakeComponent
        CompactStatus {
            textScale: Config.island.hoverTextScale
            iconScale: Config.island.hoverIconScale
            iconVerticalOffset: 1
            icon: "󰅶"
            value: ""
            showValue: false
            accent: IdleService.inhibited ? Theme.error : Theme.surfaceText
        }
    }
    Component {
        id: batteryComponent
        CompactStatus {
            textScale: Config.island.hoverTextScale
            iconScale: Config.island.hoverIconScale
            icon: BatteryService.icon
            value: BatteryService.percentageInt + "%"
            accent: BatteryService.percentageInt <= 15 && BatteryService.onBattery
                ? Theme.error : Theme.primary
        }
    }
}
