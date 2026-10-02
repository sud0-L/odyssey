import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Rectangle {
    id: root

    implicitWidth: 120
    implicitHeight: 38
    radius: height / 2
    color: SurfaceMaterial.fill(Theme.surfaceContainerHigh)
    border.width: Config.island.expandedItemBordersEnabled ? 1 : 0
    border.color: SurfaceMaterial.outline(Qt.alpha(Theme.outlineVariant, 0.55))

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.space1

        Repeater {
            model: ["previous", "toggle", "next"]
            delegate: Item {
                required property string modelData
                readonly property bool enabledAction: modelData === "previous"
                    ? MediaService.canPrevious : modelData === "next"
                    ? MediaService.canNext : MediaService.canToggle
                Layout.preferredWidth: modelData === "toggle" ? 34 : 26
                Layout.preferredHeight: 30
                opacity: enabledAction ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: modelData === "previous" ? "󰒮"
                        : modelData === "next" ? "󰒭"
                        : MediaService.playing ? "󰏤" : "󰐊"
                    color: modelData === "toggle" ? Theme.tertiary : Theme.surfaceText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Config.island.expandedPixelSize(17, true)
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: enabledAction
                    onClicked: {
                        if (modelData === "previous") MediaService.previous()
                        else if (modelData === "next") MediaService.next()
                        else MediaService.togglePlaying()
                    }
                }
            }
        }
    }
}
