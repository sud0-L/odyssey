import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

RowLayout {
    id: root

    signal pageRequested(string page)
    spacing: Theme.space2

    readonly property var latestNotification: NotificationService.history.length > 0
        ? NotificationService.history[0] : null

    function timeAgo(timestamp): string {
        if (!timestamp)
            return ""
        const minutes = Math.max(0, Math.floor((Date.now() - timestamp) / 60000))
        if (minutes < 1)
            return "Now"
        if (minutes < 60)
            return minutes + "m"
        const hours = Math.floor(minutes / 60)
        return hours < 24 ? hours + "h" : Math.floor(hours / 24) + "d"
    }

    DashboardCard {
        Layout.preferredWidth: 174
        Layout.fillHeight: true
        accent: Theme.primary
        onActivated: root.pageRequested("calendar")

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space3

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: Qt.formatDate(ShellState.now, "dddd").toUpperCase()
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(9, false)
                    font.letterSpacing: 1
                }
                Text {
                    text: Qt.formatDate(ShellState.now, "d")
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(34, false)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Qt.formatDate(ShellState.now, "MMMM yyyy")
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Config.island.expandedPixelSize(10, false)
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Text {
                    text: ShellState.time
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(17, false)
                    font.weight: Font.Bold
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: "Calendar  ›"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Config.island.expandedPixelSize(9, false)
                }
            }
        }
    }

    DashboardCard {
        id: weatherCard
        property bool weatherHovered: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        accent: Theme.tertiary
        color: weatherHovered
            ? Qt.alpha(Theme.primaryContainer, Theme.dark ? 0.48 : 0.72)
            : Qt.alpha(Theme.primaryContainer, Theme.dark ? 0.30 : 0.52)
        onActivated: root.pageRequested("weather")

        HoverHandler { onHoveredChanged: weatherCard.weatherHovered = hovered }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space1

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space3
                Text {
                    text: WeatherService.available ? WeatherService.icon : "󰖐"
                    color: Theme.tertiary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(40, true)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: WeatherService.available
                            ? WeatherService.temperatureLabel : "—"
                        color: Theme.surfaceText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(28, false)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: -4
                        text: WeatherService.statusLabel
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(10, false)
                    }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: Config.weather.locationName
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Config.island.expandedPixelSize(16, false)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: WeatherService.highLowLabel
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "Rise " + WeatherService.sunrise + "  ·  Set "
                            + WeatherService.sunset
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                }
            }

        }
    }

    DashboardCard {
        Layout.preferredWidth: 184
        Layout.fillHeight: true
        accent: Theme.primary
        onActivated: root.pageRequested("notifications")

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(14, true)
                }
                Text {
                    Layout.fillWidth: true
                    text: "NOTIFICATIONS"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(9, false)
                    font.letterSpacing: 1
                }
                Text {
                    visible: NotificationService.count > 0
                    text: NotificationService.count.toString()
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(9, false)
                    font.weight: Font.Bold
                }
            }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: root.latestNotification?.title || "You're all caught up"
                color: Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(11, false)
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: root.latestNotification
                    ? root.latestNotification.appName + " · "
                        + root.timeAgo(root.latestNotification.timestamp)
                    : "No recent notifications"
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(9, false)
            }
        }
    }

    component WeatherDatum: Item {
        id: datum
        property string icon: ""
        property string value: ""
        implicitHeight: 14

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.space1
            Text {
                text: datum.icon
                color: Theme.primary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(10, true)
            }
            Text {
                text: datum.value
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(9, false)
                font.weight: Font.DemiBold
            }
        }
    }
}
