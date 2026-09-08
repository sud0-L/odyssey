import QtQuick
import "../core"

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool available: true
    signal adjusted(real value)

    readonly property real range: Math.max(0.0001, to - from)
    readonly property real position: Math.max(0, Math.min(1,
        (value - from) / range))

    activeFocusOnTab: available
    implicitHeight: 22
    opacity: available ? 1 : 0.38

    Keys.onPressed: event => {
        if (!available)
            return
        if (event.key === Qt.Key_Left)
            adjusted(Math.max(from, value - stepSize))
        else if (event.key === Qt.Key_Right)
            adjusted(Math.min(to, value + stepSize))
        else if (event.key === Qt.Key_Home)
            adjusted(from)
        else if (event.key === Qt.Key_End)
            adjusted(to)
        else
            return
        event.accepted = true
    }

    function valueAt(mouseX: real): real {
        const normalized = Math.max(0, Math.min(1, mouseX / width))
        const raw = from + normalized * range
        return Math.max(from, Math.min(to,
            Math.round(raw / stepSize) * stepSize))
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 3
        radius: height / 2
        color: Qt.alpha(Theme.outlineVariant, 0.68)

        Rectangle {
            width: parent.width * root.position
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }

    Rectangle {
        width: root.activeFocus ? 15 : 11
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(root.width - width,
            root.width * root.position - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.primary
        border.width: 2
        border.color: Theme.surfaceContainerHigh

        Behavior on width { NumberAnimation { duration: Animations.fast } }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function updateValue(mouseX) {
            root.adjusted(root.valueAt(mouseX))
        }
        onPressed: mouse => {
            root.forceActiveFocus()
            updateValue(mouse.x)
        }
        onPositionChanged: mouse => {
            if (dragArea.pressed)
                updateValue(mouse.x)
        }
    }
}
