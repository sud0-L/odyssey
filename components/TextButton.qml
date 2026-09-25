import QtQuick
import "../core"

Rectangle {
    id: root
    property alias text: label.text
    property bool compact: false
    property bool showFocusIndicator: true
    property bool showBorder: true
    property bool busy: false
    signal clicked()

    activeFocusOnTab: true
    implicitWidth: label.implicitWidth
        + (compact ? Theme.space3 * 2 : Theme.space4 * 2)
    implicitHeight: compact ? 26 : 30
    radius: Theme.radiusSmall
    color: pointer.hovered ? Theme.primaryContainer
        : Qt.alpha(Theme.surfaceContainerHigh, 0.76)
    border.width: showBorder ? 1 : 0
    border.color: activeFocus && showFocusIndicator
        ? Qt.alpha(Theme.primary, 0.78)
        : Qt.alpha(Theme.outlineVariant, 0.34)

    Keys.onReturnPressed: if (!busy) clicked()
    Keys.onEnterPressed: if (!busy) clicked()
    Keys.onSpacePressed: if (!busy) clicked()

    Text {
        id: label
        anchors.centerIn: parent
        color: pointer.hovered ? Theme.primaryContainerText : Theme.surfaceText
        font.family: Config.appearance.fontFamily
        font.pixelSize: root.compact ? Theme.textSmall : Theme.textBody
        font.weight: Font.Medium
    }

    SequentialAnimation on opacity {
        running: root.busy && !Config.appearance.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.82; duration: 500 }
        NumberAnimation { from: 0.82; to: 1; duration: 500 }
        onStopped: root.opacity = 1
    }

    HoverHandler { id: pointer }
    TapHandler {
        enabled: !root.busy
        onTapped: {
            root.forceActiveFocus()
            root.clicked()
        }
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
