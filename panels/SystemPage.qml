import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root
    signal personalImageRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 0

            Text {
                text: "System overview"
                color: Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textTitle
                font.weight: Font.DemiBold
            }
            Text {
                text: "Live system health"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rows: 3
            columnSpacing: Theme.space3
            rowSpacing: Theme.space3

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Processor"
                value: SystemService.cpuPercent + "%"
                valueFontSize: Theme.textSmall
                detail: "Current CPU load"
                icon: "󰘚"
                level: SystemService.cpuUsage
                accent: SystemService.cpuPercent >= 90
                    ? Theme.error : Theme.primary
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Memory"
                value: SystemService.memoryPercent + "%"
                valueFontSize: Theme.textSmall
                detail: SystemService.memoryLabel
                icon: "󰍛"
                level: SystemService.memoryUsage
                accent: SystemService.memoryPercent >= 90
                    ? Theme.error : Theme.tertiary
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Storage"
                value: SystemService.storageAvailable
                    ? SystemService.diskPercent + "%" : "Unavailable"
                valueFontSize: Theme.textSmall
                detail: SystemService.diskLabel
                icon: "󰋊"
                level: SystemService.diskUsage
                accent: SystemService.diskPercent >= 90
                    ? Theme.error : Theme.secondary
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "CPU temperature"
                value: SystemService.temperatureAvailable
                    ? SystemService.temperatureInt + "°C" : "Unavailable"
                valueFontSize: Theme.textSmall
                detail: SystemService.temperatureAvailable
                    ? "Processor package sensor" : "No readable sensor"
                icon: "󰔏"
                level: SystemService.temperatureAvailable
                    ? Math.max(0, Math.min(1,
                        SystemService.temperature / 100)) : 0
                accent: SystemService.temperatureInt >= 90
                    ? Theme.error : Theme.warning
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "GPU load"
                value: SystemService.gpuUsageAvailable
                    ? SystemService.gpuPercent + "%" : "Unavailable"
                detail: SystemService.gpuUsageAvailable
                    ? "Current graphics load" : "No readable load sensor"
                icon: "󰢮"
                level: SystemService.gpuUsage
                accent: SystemService.gpuPercent >= 90
                    ? Theme.error : Theme.secondary
                valueFontSize: Theme.textSmall
            }

            SystemMetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "GPU temperature"
                value: SystemService.gpuTemperatureAvailable
                    ? SystemService.gpuTemperatureInt + "°C" : "Unavailable"
                detail: SystemService.gpuTemperatureAvailable
                    ? "Graphics edge sensor" : "No readable temperature sensor"
                icon: "󰔏"
                level: SystemService.gpuTemperatureAvailable
                    ? Math.max(0, Math.min(1,
                        SystemService.gpuTemperature / 100)) : 0
                accent: SystemService.gpuTemperatureInt >= 90
                    ? Theme.error : Theme.tertiary
                valueFontSize: Theme.textSmall
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 98
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.52)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.34)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                anchors.rightMargin: Theme.space4
                spacing: Theme.space3

                PersonalLogo {
                    Layout.preferredWidth: 190
                    Layout.fillHeight: true
                    imageMargin: Theme.space2
                    onEditRequested: root.personalImageRequested()
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 72
                    color: Qt.alpha(Theme.outlineVariant, 0.46)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    SystemInfoRow {
                        Layout.fillWidth: true
                        label: "CPU"
                        value: SystemService.cpuModel
                        accent: Theme.primary
                    }
                    SystemInfoRow {
                        Layout.fillWidth: true
                        label: "GPU"
                        value: SystemService.gpuModel
                        accent: Theme.tertiary
                    }
                    SystemInfoRow {
                        Layout.fillWidth: true
                        label: "OS"
                        value: SystemService.osName
                        accent: Theme.secondary
                    }
                    SystemInfoRow {
                        Layout.fillWidth: true
                        label: "UPTIME"
                        value: SystemService.uptimeLabel
                        accent: Theme.warning
                    }
                }
            }
        }
    }
}
