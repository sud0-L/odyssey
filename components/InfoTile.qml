import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string detail: ""
    property string icon: ""
    property color accent: Theme.primary
    property bool interactive: false

    signal activated()

    implicitHeight: 64
    radius: Theme.radiusMedium
    color: tileHover.hovered && interactive
        ? Theme.surfaceContainerHigh
        : Qt.alpha(Theme.surfaceContainerHigh, Theme.dark ? 0.86 : 0.72)
    border.color: tileHover.hovered && interactive
        ? Qt.alpha(accent, 0.56) : Qt.alpha(Theme.outlineVariant, 0.5)
    border.width: Config.island.expandedItemBordersEnabled ? 1 : 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space2

        Text {
            text: root.icon
            color: root.accent
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Config.island.expandedPixelSize(Theme.iconMedium, true)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(9, false)
                font.letterSpacing: 1
            }

            Text {
                Layout.fillWidth: true
                text: root.value
                color: Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(Theme.textBody, false)
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.detail
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Config.island.expandedPixelSize(10, false)
            }
        }
    }

    HoverHandler { id: tileHover; enabled: root.interactive }
    TapHandler {
        enabled: root.interactive
        onTapped: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
