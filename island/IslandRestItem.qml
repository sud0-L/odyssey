import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root
    required property string itemId
    property bool powerHovered: false
    signal powerRequested()
    signal captureRequested()
    implicitWidth: contentLoader.item?.implicitWidth ?? 0
    implicitHeight: 20

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.itemId === "Weather" ? weatherComponent
            : root.itemId === "Dnd" ? dndComponent
            : root.itemId === "Clock" ? clockComponent
            : root.itemId === "KeepAwake" ? keepAwakeComponent
            : root.itemId === "PowerProfile" ? powerComponent : null
    }

    Component {
        id: weatherComponent
        Item {
            visible: Config.weather.enabled && WeatherService.available
            implicitWidth: Math.round(14 * Config.island.restIconScale)
            implicitHeight: 20
            Text {
                anchors.centerIn: parent
                text: WeatherService.icon
                color: Theme.tertiary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.round(12 * Config.island.restIconScale)
            }
        }
    }

    Component {
        id: dndComponent
        Item {
            implicitWidth: Math.round(14 * Config.island.restIconScale)
            implicitHeight: 20
            Text {
                visible: NotificationService.count === 0
                anchors.centerIn: parent
                text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                color: NotificationService.doNotDisturb
                    ? Theme.tertiary : Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.round(11 * Config.island.restIconScale)
            }
            Rectangle {
                visible: NotificationService.count > 0
                anchors.centerIn: parent
                width: 13; height: 13; radius: width / 2
                color: Theme.error
                Text { anchors.fill: parent; anchors.leftMargin: 1; text: NotificationService.count > 99 ? "99+" : NotificationService.count; color: Theme.foregroundFor(parent.color); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Config.appearance.monoFontFamily; font.pixelSize: Math.round(7 * Config.island.restTextScale); font.weight: Font.Bold }
            }
            TapHandler { onTapped: NotificationService.toggleDoNotDisturb() }
        }
    }

    Component {
        id: clockComponent
        Text {
            text: ShellState.time
            color: Theme.surfaceText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Math.round(11 * Config.island.restTextScale)
            font.weight: Font.Bold
        }
    }

    Component {
        id: keepAwakeComponent
        Item {
            implicitWidth: Math.round(14 * Config.island.restIconScale)
            implicitHeight: 20
            Text {
                anchors.centerIn: parent
                text: "󰅶"
                color: IdleService.inhibited ? Theme.error : Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.round(11 * Config.island.restIconScale)
            }
            TapHandler { onTapped: IdleService.toggleInhibition() }
        }
    }

    Component {
        id: powerComponent
        Item {
            implicitWidth: 18
            implicitHeight: 20
            Text {
                visible: !CaptureService.recording
                anchors.centerIn: parent
                text: PowerProfileService.icon
                color: PowerProfileService.profileName === "Performance" ? Theme.warning
                    : PowerProfileService.profileName === "Power saver" ? Theme.success
                    : Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Math.round(11 * Config.island.restIconScale)
            }
            RecordingDot {
                anchors.centerIn: parent
                visible: CaptureService.recording
                active: visible
                dotSize: Math.round(8 * Config.island.restIconScale)
            }
            HoverHandler { onHoveredChanged: root.powerHovered = hovered }
            TapHandler {
                onTapped: CaptureService.recording
                    ? root.captureRequested() : root.powerRequested()
            }
        }
    }
}
