import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property string icon: "󰡺"
    property bool selected: false
    property bool available: true
    property bool busy: false
    property bool informationAvailable: false
    property color accent: Theme.primary

    signal activated()
    signal informationRequested()

    activeFocusOnTab: available
    opacity: available ? 1 : 0.46
    radius: Theme.radiusSmall
    color: rowHover.hovered || activeFocus
        ? Qt.alpha(Theme.surfaceContainerHigh, 0.72) : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space1
        spacing: Theme.space2

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: Theme.space2

                Item {
                    Layout.preferredWidth: 28
                    Layout.fillHeight: true

                    Text {
                        id: connectionIcon
                        anchors.centerIn: parent
                        text: root.busy ? "󰡌" : root.icon
                        color: root.selected ? root.accent : Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall

                        RotationAnimation on rotation {
                            running: root.busy && !Config.appearance.reducedMotion
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                            onStopped: connectionIcon.rotation = 0
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.detail
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 8
                    }
                }
            }

            TapHandler {
                enabled: root.available
                onTapped: root.activated()
            }
        }

        Rectangle {
            visible: root.selected
            Layout.preferredWidth: 54
            Layout.preferredHeight: 20
            radius: 10
            color: Qt.alpha(root.accent, Theme.dark ? 0.20 : 0.14)
            Text {
                anchors.centerIn: parent
                text: "Active"
                color: root.accent
                font.family: Config.appearance.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            visible: root.informationAvailable
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: infoHover.hovered ? Theme.surfaceContainerHigh : "transparent"
            Text {
                anchors.centerIn: parent
                text: "󰋼"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 13
            }
            HoverHandler { id: infoHover }
            TapHandler { onTapped: root.informationRequested() }
        }

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: actionHover.hovered ? Qt.alpha(root.accent, 0.16) : "transparent"
            Text {
                anchors.centerIn: parent
                text: root.selected ? "✓" : "›"
                color: root.selected ? root.accent : Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: root.selected ? 11 : 16
            }
            HoverHandler { id: actionHover; enabled: root.available }
            TapHandler {
                enabled: root.available
                onTapped: root.activated()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 38
        height: 1
        color: Qt.alpha(Theme.outlineVariant, 0.32)
    }

    HoverHandler { id: rowHover; enabled: root.available }
    Keys.onPressed: event => {
        if (!root.available)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.activated()
            event.accepted = true
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
