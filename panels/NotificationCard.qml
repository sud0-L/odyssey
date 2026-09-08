import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"

Rectangle {
    id: root

    required property var entry
    readonly property color accent: entry?.critical ? Theme.error : Theme.primary
    readonly property var visibleActions: NotificationService.visibleActions(entry)
    readonly property string primaryActionText: visibleActions.length > 0
        ? NotificationService.plainText(visibleActions[0].text) : ""
    readonly property string iconSource: {
        if (entry?.image)
            return entry.image
        return entry?.appIcon ? Quickshell.iconPath(entry.appIcon, true) : ""
    }

    implicitHeight: 60
    radius: Theme.radiusMedium
    color: cardHover.hovered && NotificationService.canActivate(entry)
        ? Theme.surfaceContainerHigh
        : Qt.alpha(Theme.surfaceContainerHigh, Theme.dark ? 0.78 : 0.68)
    border.width: 1
    border.color: Qt.alpha(root.accent, entry?.critical ? 0.38 : 0.12)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: Theme.space2

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: Theme.radiusSmall
            color: Qt.alpha(root.accent, Theme.dark ? 0.16 : 0.10)
            clip: true

            Image {
                id: cardIcon
                anchors.fill: parent
                anchors.margins: 7
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource.length === 0 || cardIcon.status === Image.Error
                text: root.entry?.critical ? "󰀦" : "󰂚"
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Text {
                    Layout.fillWidth: true
                    text: root.entry?.appName || "Application"
                    color: root.accent
                    elide: Text.ElideRight
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Qt.formatTime(new Date(root.entry?.timestamp || 0), "HH:mm")
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 9
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.entry?.title || "Notification"
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textSmall
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.entry?.body || ""
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }
        }

        Rectangle {
            visible: root.primaryActionText.length > 0
            Layout.preferredWidth: visible ? cardAction.implicitWidth + Theme.space3 : 0
            Layout.preferredHeight: 24
            radius: Theme.radiusSmall
            color: actionHover.hovered ? Theme.primaryContainer
                : Theme.surfaceContainer

            Text {
                id: cardAction
                anchors.centerIn: parent
                text: root.primaryActionText
                color: actionHover.hovered
                    ? Theme.primaryContainerText : Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            HoverHandler { id: actionHover }
            TapHandler { onTapped: NotificationService.invokeAction(root.entry, 0) }
        }

        Text {
            text: "󰆴"
            color: removeHover.hovered ? Theme.error : Theme.surfaceVariantText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Theme.iconSmall

            HoverHandler { id: removeHover }
            TapHandler { onTapped: NotificationService.remove(root.entry) }
        }
    }

    HoverHandler { id: cardHover }
    TapHandler {
        enabled: NotificationService.canActivate(root.entry)
        onTapped: NotificationService.activate(root.entry)
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
