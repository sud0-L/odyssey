import QtQuick
import "../core"

Rectangle {
    id: root

    property bool checked: false
    property bool available: true
    signal toggled(bool checked)

    activeFocusOnTab: available
    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2
    opacity: available ? 1 : 0.38
    color: checked ? Qt.alpha(Theme.primaryContainer, 0.96)
        : Theme.surfaceContainerHigh
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? Theme.primary
        : checked ? Qt.alpha(Theme.primary, 0.72)
        : Qt.alpha(Theme.outlineVariant, 0.64)

    Keys.onSpacePressed: if (available) toggled(!checked)
    Keys.onReturnPressed: if (available) toggled(!checked)
    Keys.onEnterPressed: if (available) toggled(!checked)

    Rectangle {
        width: 14
        height: 14
        radius: 7
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.primary : Theme.surfaceVariantText

        Behavior on x {
            NumberAnimation {
                duration: Animations.fast
                easing.type: Animations.emphasizedEase
            }
        }
    }

    TapHandler {
        enabled: root.available
        onTapped: {
            root.forceActiveFocus()
            root.toggled(!root.checked)
        }
    }
    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
