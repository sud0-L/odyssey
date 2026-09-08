import QtQuick
import "../core"

Rectangle {
    property bool active: false
    property bool occupied: false
    property bool urgent: false

    implicitWidth: active ? 18 : occupied ? 8 : 6
    implicitHeight: 6
    radius: height / 2
    color: urgent ? Theme.error : active ? Theme.primary
        : occupied ? Theme.secondary : Theme.outline

    Behavior on implicitWidth {
        NumberAnimation { duration: Animations.fast; easing.type: Animations.emphasizedEase }
    }
    Behavior on color { ColorAnimation { duration: Animations.fast } }
}
