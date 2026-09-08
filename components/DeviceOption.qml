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
    property color accent: Theme.primary

    signal activated()

    activeFocusOnTab: available
    opacity: available ? 1 : 0.46
    radius: Theme.radiusSmall
    color: selected ? Qt.alpha(accent, Theme.dark ? 0.19 : 0.13)
        : optionHover.hovered || activeFocus
            ? Theme.surfaceContainerHigh : "transparent"
    border.width: 1
    border.color: selected ? Qt.alpha(accent, 0.56)
        : activeFocus ? Qt.alpha(Theme.primary, 0.44) : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: Theme.space2

        Text {
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

        Text {
            text: root.selected ? "✓" : "›"
            color: root.selected ? root.accent : Theme.surfaceVariantText
            font.family: Config.appearance.fontFamily
            font.pixelSize: root.selected ? 12 : 17
            font.weight: Font.DemiBold
        }
    }

    HoverHandler { id: optionHover; enabled: root.available }
    TapHandler {
        enabled: root.available
        onTapped: {
            root.forceActiveFocus()
            root.activated()
        }
    }
    Keys.onPressed: event => {
        if (root.available && (event.key === Qt.Key_Space
                || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.activated()
            event.accepted = true
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
