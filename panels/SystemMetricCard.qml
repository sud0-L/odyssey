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
    property color accent: Theme.primary
    property int valueFontSize: 20

    radius: Theme.radiusLarge
    clip: true
    color: Qt.alpha(Theme.surfaceContainerHigh, 0.56)
    border.width: 1
    border.color: Qt.alpha(Theme.outlineVariant, 0.36)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space1

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Text {
                text: root.icon
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconMedium
            }
            Text {
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 8
                font.letterSpacing: 1
            }
            Text {
                text: root.value
                color: Theme.surfaceText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: root.valueFontSize
                font.weight: Font.DemiBold
            }
        }

        Item { Layout.fillHeight: true }

        LevelTrack {
            Layout.fillWidth: true
            Layout.preferredHeight: 7
            value: root.level
            accent: root.accent
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
}
