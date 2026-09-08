import QtQuick
import "../core"

Rectangle {
    id: root

    property color accent: Theme.primary
    property bool interactive: true
    signal activated()

    radius: Theme.radiusLarge
    color: cardHover.hovered && interactive
        ? Theme.surfaceContainerHigh
        : Qt.alpha(Theme.surfaceContainerHigh, 0.58)
    border.width: 1
    border.color: cardHover.hovered && interactive
        ? Qt.alpha(accent, 0.52)
        : Qt.alpha(Theme.outlineVariant, 0.36)

    HoverHandler { id: cardHover; enabled: root.interactive }
    TapHandler {
        enabled: root.interactive
        onTapped: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Animations.fast } }
    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
