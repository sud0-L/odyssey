import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space1

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Notifications"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    font.weight: Font.DemiBold
                }

                Text {
                    text: NotificationService.count === 1
                        ? "1 recent item" : NotificationService.count + " recent items"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: NotificationService.count > 0
                Layout.rightMargin: Theme.space2
                text: "Clear all"
                color: clearHover.hovered ? Theme.error : Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium

                HoverHandler { id: clearHover }
                TapHandler { onTapped: NotificationService.clearHistory() }
            }

            Rectangle {
                Layout.preferredWidth: dndContent.implicitWidth + Theme.space3 * 2
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: dndHover.hovered
                    ? (NotificationService.doNotDisturb
                        ? Theme.primaryContainer : Theme.surfaceContainerHigh)
                    : "transparent"
                border.width: dndHover.hovered ? 1 : 0
                border.color: Qt.alpha(Theme.outlineVariant, 0.54)

                RowLayout {
                    id: dndContent
                    anchors.centerIn: parent
                    spacing: Theme.space1

                    Text {
                        text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                        color: Theme.surfaceText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall
                    }

                    Text {
                        text: NotificationService.doNotDisturb ? "DND on" : "DND off"
                        // DND state is communicated by the bell; keep the label
                        // legible and stable across dark/light palettes.
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }

                HoverHandler { id: dndHover }
                TapHandler { onTapped: NotificationService.toggleDoNotDisturb() }
                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.space1
            model: NotificationService.history

            delegate: NotificationCard {
                required property var modelData
                width: historyList.width
                entry: modelData
            }

            Text {
                anchors.centerIn: parent
                visible: NotificationService.count === 0
                text: NotificationService.doNotDisturb
                    ? "Quiet mode is active" : "All quiet"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
            }
        }
    }
}
