import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"

Item {
    id: root

    readonly property var currentEntry: NotificationService.current
    // The service clears `current` before it announces a natural timeout.
    // Keep the last displayed entry only for the shared closing fade so every
    // exit looks like the reverse of the established arrival animation.
    property var retainedEntry: null
    readonly property var entry: currentEntry || retainedEntry
    readonly property color accent: entry?.critical ? Theme.error : Theme.primary
    readonly property string iconSource: {
        if (!entry)
            return ""
        if (entry.image)
            return entry.image
        return entry.appIcon ? Quickshell.iconPath(entry.appIcon, true) : ""
    }
    readonly property var visibleActions: NotificationService.visibleActions(entry)
    readonly property string primaryActionText: visibleActions.length > 0
        ? NotificationService.plainText(visibleActions[0].text) : ""

    onCurrentEntryChanged: {
        if (currentEntry)
            retainedEntry = currentEntry
    }

    TapHandler {
        enabled: root.currentEntry !== null
        onTapped: {
            if (!NotificationService.activate(root.entry))
                NotificationService.dismissTransient()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space3

        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: Theme.radiusMedium
            color: Qt.alpha(root.accent, Theme.dark ? 0.18 : 0.12)
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.30)
            clip: true

            Image {
                id: notificationIcon
                anchors.fill: parent
                anchors.margins: Theme.space2
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource.length === 0
                    || notificationIcon.status === Image.Error
                text: root.entry?.critical ? "󰀦" : "󰂚"
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconMedium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Text {
                    Layout.fillWidth: true
                    text: root.entry?.appName || "Application"
                    color: root.accent
                    elide: Text.ElideRight
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: root.entry?.critical ?? false
                    text: "CRITICAL"
                    color: Theme.error
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.entry?.title || "Notification"
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
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
                font.pixelSize: Theme.textSmall
            }
        }

        Rectangle {
            visible: root.primaryActionText.length > 0
            Layout.preferredWidth: visible ? actionLabel.implicitWidth + Theme.space3 * 2 : 0
            Layout.preferredHeight: 30
            radius: Theme.radiusSmall
            color: actionPointer.hovered ? Theme.primaryContainer
                : Theme.surfaceContainerHigh

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: root.primaryActionText
                color: actionPointer.hovered
                    ? Theme.primaryContainerText : Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textSmall
                font.weight: Font.Medium
            }

            HoverHandler { id: actionPointer }
            TapHandler { onTapped: NotificationService.invokeAction(root.entry, 0) }
        }
    }
}
