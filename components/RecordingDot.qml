import QtQuick
import "../core"

Rectangle {
    id: root

    property bool active: false
    property int dotSize: 8

    width: dotSize
    height: dotSize
    radius: dotSize / 2
    color: Theme.error
    opacity: 1

    SequentialAnimation {
        id: pulse
        running: root.active && !Config.appearance.reducedMotion
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0.38
            duration: 900
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0.38
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }

        onRunningChanged: {
            if (!running)
                root.opacity = 1
        }
    }
}
