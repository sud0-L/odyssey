import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    readonly property var metrics: [
        { label: "Humidity", value: WeatherService.humidity + "%",
            detail: "Relative humidity", icon: "󰖎", accent: Theme.primary },
        { label: "Wind", value: WeatherService.windLabel,
            detail: "At 10 metres", icon: "󰖝", accent: Theme.tertiary },
        { label: "Precipitation", value: WeatherService.precipitationChance + "%",
            detail: WeatherService.precipitation.toFixed(1) + " mm now",
            icon: "󰖗", accent: Theme.primary },
        { label: "UV index", value: WeatherService.uvIndex.toString(),
            detail: WeatherService.uvIndex >= 6 ? "Use sun protection"
                : WeatherService.uvIndex >= 3 ? "Moderate exposure" : "Low exposure",
            icon: "󰖙", accent: Theme.warning },
        { label: "Visibility", value: WeatherService.visibilityLabel,
            detail: "Current horizontal range", icon: "󰈈", accent: Theme.secondary },
        { label: "Pressure", value: WeatherService.pressureLabel,
            detail: "Surface pressure", icon: "󰓅", accent: Theme.tertiary },
        { label: "Sunrise", value: WeatherService.sunrise,
            detail: "Local time", icon: "󰖛", accent: Theme.warning },
        { label: "Sunset", value: WeatherService.sunset,
            detail: "Local time", icon: "󰖚", accent: Theme.tertiary }
    ]

    Flickable {
        id: weatherScroll
        anchors.fill: parent
        visible: WeatherService.available
        contentWidth: width
        contentHeight: weatherContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: weatherContent
            width: weatherScroll.width - Theme.space2
            spacing: Theme.space2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                radius: Theme.radiusLarge
                color: Qt.alpha(Theme.primaryContainer, Theme.dark ? 0.28 : 0.48)
                border.width: 1
                border.color: Qt.alpha(Theme.primary, 0.26)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space4
                    spacing: Theme.space4

                    Text {
                        text: WeatherService.icon
                        color: Theme.tertiary
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 48
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 170
                        spacing: 0
                        Text {
                            text: WeatherService.temperatureLabel
                            color: Theme.surfaceText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: 44
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: WeatherService.condition
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: WeatherService.feelsLikeLabel + "  ·  "
                                + WeatherService.highLowLabel
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 9
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 1
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: Config.weather.locationName
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textTitle
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: "Updated " + Qt.formatTime(WeatherService.lastUpdated, "HH:mm")
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: 8
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: "󰑐  Refresh"
                            color: refreshHover.hovered ? Theme.primary
                                : Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 9
                            HoverHandler { id: refreshHover }
                            TapHandler { onTapped: WeatherService.refresh() }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: Theme.radiusMedium
                color: Qt.alpha(Theme.surfaceContainerHigh, 0.54)
                border.width: 1
                border.color: Qt.alpha(Theme.outlineVariant, 0.32)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space3
                    spacing: Theme.space2

                    Text {
                        text: "HOURLY FORECAST"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 0.9
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(parent.width,
                            Config.insights.hourlyPreviewCount * 54
                                + (Config.insights.hourlyPreviewCount - 1)
                                    * Theme.space1)
                        Layout.fillHeight: true
                        spacing: Theme.space1

                        Repeater {
                            model: WeatherService.hourlyForecast.slice(0,
                                Config.insights.hourlyPreviewCount)
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.preferredWidth: 54
                                Layout.fillHeight: true
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.time
                                    color: Theme.surfaceVariantText
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 8
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: Theme.primary
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.temperature + "°"
                                    color: Theme.surfaceText
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: modelData.precipitation > 0
                                    text: modelData.precipitation + "%"
                                    color: Theme.primary
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 218
                radius: Theme.radiusMedium
                color: Qt.alpha(Theme.surfaceContainerHigh, 0.54)
                border.width: 1
                border.color: Qt.alpha(Theme.outlineVariant, 0.32)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space3
                    spacing: Theme.space1
                    Text {
                        Layout.preferredHeight: 20
                        text: "7-DAY FORECAST"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 9
                        font.letterSpacing: 0.9
                    }
                    Repeater {
                        model: WeatherService.forecast.slice(0,
                            Config.insights.dailyPreviewCount)
                        delegate: Rectangle {
                            id: dailyRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: index === 0
                                ? Qt.alpha(Theme.primaryContainer, 0.22)
                                : index % 2 === 0
                                    ? Qt.alpha(Theme.surfaceContainerLow, 0.28)
                                    : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space2
                                anchors.rightMargin: Theme.space2
                                spacing: Theme.space2
                                Text {
                                    Layout.preferredWidth: 66
                                    text: dailyRow.modelData.day
                                    color: Theme.surfaceText
                                    font.family: Config.appearance.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.preferredWidth: 28
                                    horizontalAlignment: Text.AlignHCenter
                                    text: dailyRow.modelData.icon
                                    color: Theme.primary
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 15
                                }
                                RowLayout {
                                    Layout.preferredWidth: 62
                                    spacing: Theme.space1
                                    Text {
                                        text: "󰖗"
                                        color: dailyRow.modelData.precipitation > 0
                                            ? Theme.primary
                                            : Theme.surfaceVariantText
                                        opacity: dailyRow.modelData.precipitation > 0
                                            ? 1 : 0.34
                                        font.family: Config.appearance.monoFontFamily
                                        font.pixelSize: 11
                                    }
                                    Text {
                                        text: dailyRow.modelData.precipitation + "%"
                                        color: Theme.surfaceVariantText
                                        font.family: Config.appearance.monoFontFamily
                                        font.pixelSize: 9
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                    text: dailyRow.modelData.low + "°"
                                    color: Theme.surfaceVariantText
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 10
                                }
                                Rectangle {
                                    Layout.preferredWidth: 132
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: Qt.alpha(Theme.surfaceVariantText, 0.14)
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.width * 0.16
                                        width: parent.width * 0.68
                                        height: parent.height
                                        radius: 3
                                        color: Theme.tertiary
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 32
                                    text: dailyRow.modelData.high + "°"
                                    color: Theme.surfaceText
                                    font.family: Config.appearance.monoFontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.space2
                rowSpacing: Theme.space2

                Repeater {
                    model: root.metrics
                    delegate: WeatherMetric {
                        required property var modelData
                        Layout.fillWidth: true
                        label: modelData.label
                        value: modelData.value
                        detail: modelData.detail
                        icon: modelData.icon
                        accent: modelData.accent
                    }
                }
            }
        }

        Rectangle {
            visible: weatherScroll.contentHeight > weatherScroll.height
            anchors.right: parent.right
            width: 2
            height: Math.max(24, parent.height * weatherScroll.visibleArea.heightRatio)
            y: parent.height * weatherScroll.visibleArea.yPosition
            radius: 1
            color: Qt.alpha(Theme.primary, 0.48)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !WeatherService.available
        spacing: Theme.space3

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: WeatherService.loading ? "󰡌" : "󰖐"
            color: Theme.tertiary
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 36
            RotationAnimation on rotation {
                running: WeatherService.loading
                    && !Config.appearance.reducedMotion
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: WeatherService.statusLabel
            color: Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: Font.DemiBold
        }
        Text {
            visible: !WeatherService.loading
            Layout.alignment: Qt.AlignHCenter
            text: WeatherService.configured
                ? "Retry forecast" : "Configure a location in Dashboard settings"
            color: Theme.primary
            font.family: Config.appearance.fontFamily
            font.pixelSize: 10
            TapHandler {
                enabled: WeatherService.configured
                onTapped: WeatherService.refresh()
            }
        }
    }
}
