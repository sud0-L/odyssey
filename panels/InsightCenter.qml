import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    property string selectedPage: "weather"
    signal pageRequested(string page)
    signal personalImageRequested()

    readonly property var pages: [
        { id: "weather", label: "Weather", icon: "󰖐" },
        { id: "calendar", label: "Calendar", icon: "󰃭" },
        { id: "media-center", label: "Media", icon: "󰎆" },
        { id: "system", label: "System", icon: "󰍛" },
        { id: "battery", label: "Battery", icon: "󰁹" }
    ]
    readonly property int pageIndex: Math.max(0,
        pages.findIndex(option => option.id === selectedPage))

    onSelectedPageChanged: pageReveal.restart()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.58)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.34)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3

                Repeater {
                    model: root.pages
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected:
                            modelData.id === root.selectedPage
                        visible: modelData.id !== "battery"
                            || BatteryService.available
                        Layout.fillWidth: visible
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: selected ? Theme.primaryContainer
                            : tabHover.hovered ? Theme.surfaceContainerHigh : "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.space1
                            Text {
                                text: modelData.icon
                                color: selected ? Theme.primaryContainerText
                                    : Theme.surfaceVariantText
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.label
                                color: selected ? Theme.primaryContainerText
                                    : Theme.surfaceVariantText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 10
                                font.weight: selected ? Font.DemiBold : Font.Medium
                            }
                        }

                        HoverHandler { id: tabHover }
                        TapHandler { onTapped: root.pageRequested(modelData.id) }
                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }
                    }
                }
            }
        }

        Item {
            id: pageContent
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                anchors.fill: parent
                currentIndex: root.pageIndex

                WeatherPage { }
                CalendarPage { }
                MediaPage { }
                SystemPage {
                    onPersonalImageRequested: root.personalImageRequested()
                }
                BatteryPage { }
            }
        }
    }

    Connections {
        target: BatteryService
        function onAvailableChanged(): void {
            if (!BatteryService.available && root.selectedPage === "battery")
                root.pageRequested("weather")
        }
    }

    NumberAnimation {
        id: pageReveal
        target: pageContent
        property: "opacity"
        from: 0.42
        to: 1
        duration: Config.insights.pageTransition
        easing.type: Animations.emphasizedEase
    }
}
