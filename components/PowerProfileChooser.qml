import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Rectangle {
    id: root

    property color feedbackAccent: "transparent"
    property real feedbackStrength: 0

    signal profileChosen(string profileId)

    radius: Theme.radiusMedium
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: Qt.alpha(Theme.outlineVariant, 0.52)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space1
        spacing: Theme.space1

        Repeater {
            model: PowerProfileService.options

            delegate: Rectangle {
                id: option
                required property var modelData

                readonly property bool active:
                    PowerProfileService.profileId === modelData.id
                readonly property bool selectable: modelData.available

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusSmall
                color: active ? Qt.tint(Theme.primaryContainer,
                    Qt.alpha(root.feedbackAccent,
                        root.feedbackStrength * 0.72))
                    : optionHover.hovered && selectable
                        ? Theme.surfaceContainer : "transparent"
                opacity: selectable ? 1 : 0.42

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space2

                    Text {
                        text: option.modelData.icon
                        color: option.active ? Theme.primaryContainerText
                            : Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall
                    }

                    Text {
                        text: option.modelData.name
                        color: option.active ? Theme.primaryContainerText
                            : Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        font.weight: option.active ? Font.DemiBold : Font.Medium
                    }
                }

                HoverHandler { id: optionHover; enabled: option.selectable }
                TapHandler {
                    enabled: option.selectable
                    onTapped: {
                        PowerProfileService.setProfileId(option.modelData.id)
                        root.profileChosen(option.modelData.id)
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animations.profileFeedbackRise
                        easing.type: Animations.emphasizedEase
                    }
                }
            }
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.normal } }
    Behavior on border.color { ColorAnimation { duration: Animations.normal } }
}
