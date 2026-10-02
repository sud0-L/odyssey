import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

Rectangle {
    id: root

    property string label: "Metric"
    property string value: "Unavailable"
    property string detail: ""
    property string icon: "󰍛"
    property real level: 0
    property bool showLevel: true
    property color accent: Theme.primary
    property int valueFontSize: 20

    radius: Theme.radiusLarge
    clip: true
    color: Qt.alpha(Theme.surfaceContainerHigh, 0.56)
    border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
    border.color: Qt.alpha(Theme.outlineVariant, 0.36)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space3
        anchors.rightMargin: Theme.space3
        anchors.topMargin: root.height < 72 ? Theme.space2 : Theme.space3
        anchors.bottomMargin: root.height < 72 ? Theme.space2 : Theme.space3
        spacing: Theme.space1

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Text {
                text: root.icon
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(Theme.iconMedium, true)
            }
            Text {
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(8, false)
                font.letterSpacing: 1
            }
            Text {
                text: root.value
                color: Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Config.island.expandedPixelSize(root.valueFontSize, false)
                font.weight: Font.DemiBold
            }
        }

        Item { Layout.fillHeight: true }

        LevelTrack {
            visible: root.showLevel
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            value: root.level
            accent: root.accent
        }
        Text {
            visible: root.detail.length > 0
                && root.height >= (root.showLevel ? 84 : 58)
            Layout.fillWidth: true
            text: root.detail
            color: Theme.surfaceVariantText
            elide: Text.ElideRight
            font.family: Config.appearance.fontFamily
            font.pixelSize: Config.island.expandedPixelSize(9, false)
        }
    }
}
