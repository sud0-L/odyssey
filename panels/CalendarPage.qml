import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property date displayedMonth: new Date(ShellState.now.getFullYear(),
        ShellState.now.getMonth(), 1)
    property date selectedDate: new Date(ShellState.now.getFullYear(),
        ShellState.now.getMonth(), ShellState.now.getDate())
    // Future calendar providers can populate this without changing the month UI.
    property var events: []
    readonly property var weekdayLabels: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var monthCells: buildMonthCells()

    function sameDay(first, second): bool {
        return first.getFullYear() === second.getFullYear()
            && first.getMonth() === second.getMonth()
            && first.getDate() === second.getDate()
    }

    function buildMonthCells(): var {
        const year = displayedMonth.getFullYear()
        const month = displayedMonth.getMonth()
        const firstWeekday = new Date(year, month, 1).getDay()
        const cells = []
        for (let index = 0; index < 42; index++) {
            const date = new Date(year, month, index - firstWeekday + 1)
            cells.push({
                date: date,
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                today: sameDay(date, ShellState.now),
                selected: sameDay(date, selectedDate)
            })
        }
        return cells
    }

    function changeMonth(offset): void {
        displayedMonth = new Date(displayedMonth.getFullYear(),
            displayedMonth.getMonth() + offset, 1)
    }

    function returnToToday(): void {
        selectedDate = new Date(ShellState.now.getFullYear(),
            ShellState.now.getMonth(), ShellState.now.getDate())
        displayedMonth = new Date(ShellState.now.getFullYear(),
            ShellState.now.getMonth(), 1)
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space3

        Rectangle {
            Layout.preferredWidth: 188
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.primaryContainer, Theme.dark ? 0.25 : 0.42)
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.24)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space4
                spacing: Theme.space2

                Text {
                    text: Qt.formatDate(root.selectedDate, "dddd").toUpperCase()
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1.1
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Qt.formatDate(root.selectedDate, "d")
                    color: Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 54
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Qt.formatDate(root.selectedDate, "MMMM yyyy")
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.alpha(Theme.outlineVariant, 0.42)
                }

                Text {
                    text: "SCHEDULE"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 8
                    font.letterSpacing: 1
                }
                Text {
                    Layout.fillWidth: true
                    text: root.events.length > 0
                        ? root.events.length + " events" : "Nothing scheduled"
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Calendar providers will appear here when connected."
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: todayHover.hovered ? Theme.primaryContainer
                        : Theme.surfaceContainerHigh
                    Text {
                        anchors.centerIn: parent
                        text: "Return to today"
                        color: todayHover.hovered ? Theme.primaryContainerText
                            : Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: todayHover }
                    TapHandler { onTapped: root.returnToToday() }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.52)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.34)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space4
                spacing: Theme.space2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.displayedMonth, "MMMM yyyy")
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textTitle
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: [
                            { icon: "‹", offset: -1 },
                            { icon: "›", offset: 1 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSmall
                            color: monthHover.hovered
                                ? Theme.surfaceContainerHigh : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: Theme.surfaceVariantText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 18
                            }
                            HoverHandler { id: monthHover }
                            TapHandler { onTapped: root.changeMonth(modelData.offset) }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    columns: 7
                    columnSpacing: 4
                    Repeater {
                        model: root.weekdayLabels
                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: 7
                            font.weight: Font.DemiBold
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rows: 6
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: root.monthCells
                        delegate: Rectangle {
                            id: dayCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSmall
                            color: modelData.selected ? Theme.primary
                                : modelData.today ? Qt.alpha(Theme.primary, 0.16)
                                : dayHover.hovered ? Theme.surfaceContainerHigh
                                : "transparent"
                            border.width: modelData.today && !modelData.selected ? 1 : 0
                            border.color: Qt.alpha(Theme.primary, 0.54)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.selected ? Theme.primaryText
                                    : modelData.inMonth ? Theme.surfaceText
                                    : Qt.alpha(Theme.surfaceVariantText, 0.38)
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: 9
                                font.weight: modelData.today || modelData.selected
                                    ? Font.Bold : Font.Normal
                            }
                            HoverHandler { id: dayHover }
                            TapHandler {
                                onTapped: {
                                    root.selectedDate = dayCell.modelData.date
                                    if (!dayCell.modelData.inMonth)
                                        root.displayedMonth = new Date(
                                            dayCell.modelData.date.getFullYear(),
                                            dayCell.modelData.date.getMonth(), 1)
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: Animations.fast }
                            }
                        }
                    }
                }
            }
        }
    }
}
