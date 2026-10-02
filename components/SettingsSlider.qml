import QtQuick
import "../core"

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool available: true
    property bool applyOnRelease: false
    signal adjusted(real value)

    readonly property real range: Math.max(0.0001, to - from)
    readonly property real visualValue: dragArea.dragging
        ? dragArea.pendingValue : value
    readonly property real position: Math.max(0, Math.min(1,
        (visualValue - from) / range))

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
        border.width: Config.island.expandedItemBordersEnabled ? 2 : 0
        border.color: Theme.surfaceContainerHigh

        Behavior on width { NumberAnimation { duration: Animations.fast } }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real dragStartGlobalX: 0
        property real dragStartValue: 0
        property real dragStartGlobalWidth: 1
        property bool dragging: false
        property real pendingValue: 0
        function globalX(mouseX, mouseY) {
            return root.mapToGlobal(mouseX, mouseY).x
        }
        function updateValue(mouseX, mouseY) {
            if (root.applyOnRelease) {
                pendingValue = root.valueAt(mouseX)
                return
            }
            const globalDelta = globalX(mouseX, mouseY) - dragStartGlobalX
            const raw = dragStartValue + globalDelta / dragStartGlobalWidth
                * root.range
            const next = Math.max(root.from, Math.min(root.to,
                Math.round(raw / root.stepSize) * root.stepSize))
            pendingValue = next
            if (!root.applyOnRelease)
                root.adjusted(next)
        }
        onPressed: mouse => {
            root.forceActiveFocus()
            if (!root.applyOnRelease) {
                dragStartGlobalX = globalX(mouse.x, mouse.y)
                dragStartGlobalWidth = Math.max(1, Math.abs(
                    root.mapToGlobal(root.width, 0).x
                    - root.mapToGlobal(0, 0).x))
            }
            dragStartValue = root.valueAt(mouse.x)
            pendingValue = dragStartValue
            dragging = true
            if (!root.applyOnRelease)
                root.adjusted(dragStartValue)
        }
        onPositionChanged: mouse => {
            if (dragArea.pressed)
                updateValue(mouse.x, mouse.y)
        }
        onReleased: {
            if (root.applyOnRelease)
                root.adjusted(pendingValue)
            dragging = false
        }
        onCanceled: dragging = false
    }
}
