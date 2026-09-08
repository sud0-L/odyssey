import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 0

            Text {
                text: "Battery"
                color: Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textTitle
                font.weight: Font.DemiBold
            }
            Text {
                text: "Power, endurance, and long-term health"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.surfaceContainer, 0.74)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.42)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space4
                spacing: Theme.space4

                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76
                    radius: 38
                    color: Qt.alpha(Theme.primaryContainer, 0.70)

                    Text {
                        anchors.centerIn: parent
                        text: BatteryService.icon
                        color: Theme.primaryContainerText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 30
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
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: BatteryService.statusLabel
                            color: BatteryService.percentageInt <= 15
                                && BatteryService.onBattery
                                ? Theme.error : Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textSmall
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
                        font.pixelSize: 9
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
                icon: "󰚥"
                accent: Theme.tertiary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.52)
            border.width: 1
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
                    font.pixelSize: 13
                }
                Text {
                    text: "Current capacity"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: BatteryService.capacityLabel
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
