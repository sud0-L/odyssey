import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 0

            Text {
                text: "Battery"
                color: Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(Theme.textTitle, false)
                font.weight: Font.DemiBold
            }
            Text {
                text: "Power, endurance, and long-term health"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(9, false)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 94
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.surfaceContainer, 0.74)
            border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
            border.color: Qt.alpha(Theme.outlineVariant, 0.42)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space3
                spacing: Theme.space3

                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    radius: 30
                    color: Qt.alpha(Theme.primaryContainer, 0.70)

                    Text {
                        anchors.centerIn: parent
                        text: BatteryService.icon
                        color: Theme.primaryContainerText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(30, true)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space1

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: BatteryService.percentageInt + "%"
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Config.island.expandedPixelSize(28, false)
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: BatteryService.statusLabel
                            color: BatteryService.percentageInt <= 15
                                && BatteryService.onBattery
                                ? Theme.error : Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Config.island.expandedPixelSize(Theme.textSmall, false)
                        }
                    }

                    LevelTrack {
                        Layout.fillWidth: true
                        value: BatteryService.percentage
                        accent: BatteryService.percentageInt <= 15
                            && BatteryService.onBattery
                            ? Theme.error : Theme.primary
                    }

                    Text {
                        text: BatteryService.sourceLabel + " · "
                            + BatteryService.modelLabel
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Config.island.expandedPixelSize(9, false)
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rows: 2
            columnSpacing: Theme.space3
            rowSpacing: Theme.space3

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Battery health"
                value: BatteryService.healthAvailable
                    ? BatteryService.healthPercentageInt + "%" : "Unavailable"
                valueFontSize: Theme.textSmall
                detail: BatteryService.healthLabel
                showLevel: BatteryService.healthAvailable
                level: BatteryService.healthPercentage / 100
                icon: "󰂑"
                accent: !BatteryService.healthAvailable ? Theme.surfaceVariantText
                    : BatteryService.healthPercentageInt < 65 ? Theme.error
                    : BatteryService.healthPercentageInt < 80 ? Theme.warning
                    : Theme.success
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Until charged"
                value: BatteryService.chargeTimeLabel
                valueFontSize: Theme.textSmall
                detail: BatteryService.charging
                    ? "Estimated time to full" : "Connect AC power to charge"
                showLevel: BatteryService.charging
                level: BatteryService.percentage
                icon: "󰔛"
                accent: Theme.success
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Time remaining"
                value: BatteryService.emptyTimeLabel
                valueFontSize: Theme.textSmall
                detail: BatteryService.onBattery
                    ? "Estimated runtime" : "Running from external power"
                showLevel: BatteryService.onBattery
                level: BatteryService.percentage
                icon: "󰥔"
                accent: BatteryService.percentageInt <= 15
                    && BatteryService.onBattery ? Theme.error : Theme.primary
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: BatteryService.charging ? "Charge rate" : "Power draw"
                value: BatteryService.chargeRateLabel
                valueFontSize: Theme.textSmall
                detail: "Live battery energy rate"
                showLevel: false
                icon: "󰚥"
                accent: Theme.tertiary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.52)
            border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
            border.color: Qt.alpha(Theme.outlineVariant, 0.34)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                spacing: Theme.space3

                Text {
                    text: "󰁹"
                    color: Theme.secondary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(13, true)
                }
                Text {
                    text: "Current capacity"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Config.island.expandedPixelSize(Theme.textSmall, false)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: BatteryService.capacityLabel
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(Theme.textSmall, false)
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
