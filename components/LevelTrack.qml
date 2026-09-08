import QtQuick
import "../core"

Item {
    id: root

    property real value: 0
    property color accent: Theme.primary

    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.surfaceVariantText, 0.16)
    }

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: height / 2
        color: root.accent

        Behavior on width {
            NumberAnimation { duration: Animations.fast; easing.type: Animations.emphasizedEase }
        }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }
}
