import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space3

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: 21
            color: CaptureService.errorMessage
                ? Qt.alpha(Theme.error, 0.18)
                : Qt.alpha(Theme.success, 0.18)

            Text {
                anchors.centerIn: parent
                text: CaptureService.errorMessage ? "󰅙" : "󰄀"
                color: CaptureService.errorMessage ? Theme.error : Theme.success
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconMedium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: CaptureService.statusMessage
                color: Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: CaptureService.lastOutputPath.length > 0
                text: CaptureService.fileName(CaptureService.lastOutputPath)
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
