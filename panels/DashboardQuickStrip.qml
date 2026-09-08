import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

RowLayout {
    id: root

    signal pageRequested(string page)
    spacing: Theme.space2

    readonly property var statuses: [
        { label: "Audio", value: AudioService.available
                ? (AudioService.muted ? "Muted" : AudioService.volumePercent + "%")
                : "Unavailable", icon: AudioService.muted ? "󰝟" : "󰕾",
            accent: AudioService.muted ? Theme.error : Theme.primary,
            page: "control-center", available: true },
        { label: "Network", value: NetworkService.available
                ? NetworkService.connectionName : "Unavailable",
            icon: NetworkService.icon,
            accent: NetworkService.connected ? Theme.primary : Theme.error,
            page: "control-center", available: true },
        { label: "Bluetooth", value: BluetoothService.statusLabel,
            icon: BluetoothService.icon,
            accent: BluetoothService.connected ? Theme.primary
                : Theme.surfaceVariantText,
            page: "control-center", available: BluetoothService.available },
        { label: "Focus", value: NotificationService.doNotDisturb ? "DND on" : "DND off",
            icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚",
            accent: NotificationService.doNotDisturb ? Theme.tertiary : Theme.primary,
            page: "notifications", available: true },
        { label: "Power", value: PowerProfileService.profileName,
            icon: PowerProfileService.icon,
            accent: PowerProfileService.profileId === "performance"
                ? Theme.warning : Theme.success,
            page: "control-center", available: PowerProfileService.available },
        { label: "Wallpaper", value: WallpaperService.currentName,
            icon: "󰸉", accent: Theme.tertiary,
            page: "wallpaper", available: true }
    ]

    Repeater {
        model: root.statuses
        delegate: Rectangle {
            required property var modelData
            visible: modelData.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: quickHover.hovered
                ? Theme.surfaceContainerHigh
                : Qt.alpha(Theme.surfaceContainerHigh, 0.48)
            border.width: 1
            border.color: quickHover.hovered
                ? Qt.alpha(modelData.accent, 0.48)
                : Qt.alpha(Theme.outlineVariant, 0.30)

            GridLayout {
                anchors.centerIn: parent
                columns: 2
                rows: 2
                columnSpacing: Theme.space1
                rowSpacing: 0
                Text {
                    Layout.rowSpan: 1
                    Layout.alignment: Qt.AlignVCenter
                    text: modelData.icon
                    color: modelData.accent
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 15
                }
                Text {
                    text: modelData.label
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                Item {
                    Layout.preferredWidth: 15
                    Layout.preferredHeight: 1
                }
                Text {
                    Layout.preferredWidth: Math.max(48,
                        parent.width - 15 - Theme.space1)
                    text: modelData.value
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 8
                }
            }

            HoverHandler { id: quickHover }
            TapHandler { onTapped: root.pageRequested(modelData.page) }
            Behavior on color { ColorAnimation { duration: Animations.fast } }
            Behavior on border.color { ColorAnimation { duration: Animations.fast } }
        }
    }
}
