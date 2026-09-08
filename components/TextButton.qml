import QtQuick
import "../core"

Rectangle {
    id: root
    property alias text: label.text
    property bool compact: false
    property bool showFocusIndicator: true
    signal clicked()

    activeFocusOnTab: true
    implicitWidth: label.implicitWidth
        + (compact ? Theme.space3 * 2 : Theme.space4 * 2)
    implicitHeight: compact ? 26 : 30
    radius: Theme.radiusSmall
    color: pointer.hovered ? Theme.primaryContainer
        : Qt.alpha(Theme.surfaceContainerHigh, 0.76)
    border.width: 1
    border.color: activeFocus && showFocusIndicator
        ? Qt.alpha(Theme.primary, 0.78)
        : Qt.alpha(Theme.outlineVariant, 0.34)

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    Text {
        id: label
        anchors.centerIn: parent
        color: pointer.hovered ? Theme.primaryContainerText : Theme.surfaceText
        font.family: Config.appearance.fontFamily
        font.pixelSize: root.compact ? Theme.textSmall : Theme.textBody
        font.weight: Font.Medium
    }

    HoverHandler { id: pointer }
    TapHandler {
        onTapped: {
            root.forceActiveFocus()
            root.clicked()
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
