import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property string icon: ""
    property bool checked: false
    property bool available: true
    property color accent: Theme.primary
    property bool expandable: false
    property bool expanded: false

    signal activated()
    signal toggleRequested()

    activeFocusOnTab: available
    opacity: available ? 1 : 0.42
    radius: Theme.radiusMedium
    color: checked ? Qt.alpha(accent, Theme.dark ? 0.22 : 0.15)
        : tileHover.hovered || activeFocus ? Theme.surfaceContainerHigh
        : Qt.alpha(Theme.surfaceContainer, 0.78)
    border.width: 1
    border.color: checked ? Qt.alpha(accent, 0.62)
        : activeFocus ? Qt.alpha(Theme.primary, 0.52)
        : Qt.alpha(Theme.outlineVariant, 0.48)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: Theme.space2

        Rectangle {
            id: iconButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: Theme.radiusSmall
            color: root.checked ? Qt.alpha(root.accent, 0.20)
                : Theme.surfaceContainerHigh

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.checked ? root.accent : Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
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
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.detail
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }
        Text {
            visible: root.expandable
            text: "󰅀"
            color: root.expanded ? root.accent : Theme.surfaceVariantText
            rotation: root.expanded ? 180 : 0
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 13

            Behavior on rotation {
                NumberAnimation {
                    duration: Animations.normal
                    easing.type: Animations.emphasizedEase
                }
            }
        }
    }

    HoverHandler { id: tileHover; enabled: root.available }
    TapHandler {
        enabled: root.available
        onTapped: eventPoint => {
            root.forceActiveFocus()
            const point = eventPoint.position
            const iconHit = root.expandable && point.x >= iconButton.x
                && point.x <= iconButton.x + iconButton.width
                && point.y >= iconButton.y
                && point.y <= iconButton.y + iconButton.height
            if (iconHit)
                root.toggleRequested()
            else
                root.activated()
        }
    }
    Keys.onPressed: event => {
        if (!root.available)
            return
        if (root.expandable && event.key === Qt.Key_Space) {
            root.toggleRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activated()
            event.accepted = true
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
