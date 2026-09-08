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

    implicitHeight: 74
    radius: Theme.radiusMedium
    color: Qt.alpha(Theme.surfaceContainerHigh, Theme.dark ? 0.58 : 0.72)
    border.width: 1
    border.color: Qt.alpha(Theme.outlineVariant, 0.34)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.icon
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                text: root.label.toUpperCase()
                color: Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 8
                font.letterSpacing: 0.8
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.value
            color: Theme.surfaceText
            elide: Text.ElideRight
            font.family: Config.appearance.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.detail
            color: Theme.surfaceVariantText
            elide: Text.ElideRight
            font.family: Config.appearance.fontFamily
            font.pixelSize: 8
        }
    }
}
