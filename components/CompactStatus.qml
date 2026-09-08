import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string icon: ""
    property string value: ""
    property color accent: Theme.primary
    property real textScale: 1
    property real iconScale: 1
    property real iconVerticalOffset: 0
    property bool showValue: value.length > 0

    implicitWidth: 72
    implicitHeight: 32

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.space1

        Text {
            text: root.icon
            color: root.accent
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Math.round(Theme.iconSmall * root.iconScale)
            transform: Translate { y: root.iconVerticalOffset }
        }

        Text {
            visible: root.showValue
            text: root.value
            color: Theme.surfaceVariantText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Math.round(Theme.textSmall * root.textScale)
            font.weight: Font.DemiBold
        }
    }
}
