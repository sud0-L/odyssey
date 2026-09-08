import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property string label: "SYSTEM"
    property string value: "Unavailable"
    property color accent: Theme.primary

    implicitHeight: 18

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Text {
            Layout.preferredWidth: 52
            text: root.label
            color: root.accent
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 8
            font.weight: Font.Bold
            font.letterSpacing: 0.8
        }
        Text {
            Layout.fillWidth: true
            text: root.value
            color: Theme.surfaceText
            elide: Text.ElideRight
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 9
        }
    }
}
