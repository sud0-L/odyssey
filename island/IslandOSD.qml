import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"

Item {
    id: root

    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property string deviceName: ""

    readonly property bool microphone: kind === "microphone"
    readonly property bool brightness: kind === "brightness"
    readonly property bool powerProfile: kind === "powerProfile"
    readonly property color accent: muted ? Theme.error : Theme.primary
    readonly property string icon: powerProfile
        ? (level < 0.4 ? "󰌪" : level > 0.85 ? "󰓅" : "󰾅")
        : brightness ? "󰃠" : microphone
        ? (muted ? "󰍭" : "󰍬")
        : (muted || level <= 0 ? "󰝟" : level < 0.5 ? "󰖀" : "󰕾")
    readonly property string title: powerProfile ? deviceName
        : brightness ? "Brightness" : microphone
        ? (muted ? "Microphone muted" : "Microphone active")
        : (muted ? "Audio muted" : "Volume")
    readonly property string detail: powerProfile ? "Power profile selected" : deviceName

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space4
        anchors.rightMargin: Theme.space4
        spacing: Theme.space3

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: Theme.radiusMedium
            color: Qt.alpha(root.accent, Theme.dark ? 0.18 : 0.13)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconMedium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.powerProfile ? "ACTIVE"
                        : root.muted && !root.brightness
                            ? "OFF" : Math.round(root.level * 100) + "%"
                    color: root.accent
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.Bold
                }
            }

            LevelTrack {
                Layout.fillWidth: true
                value: root.muted && !root.brightness ? 0 : root.level
                accent: root.accent
            }

            Text {
                Layout.fillWidth: true
                text: root.detail
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }
        }
    }
}
