import QtQuick
import "../core"

Rectangle {
    color: Qt.alpha(Theme.surfaceContainer, Config.appearance.surfaceOpacity)
    border.color: Qt.alpha(Theme.outlineVariant, Theme.dark ? 0.62 : 0.48)
    border.width: 1
    radius: Theme.radiusLarge

    Behavior on color { ColorAnimation { duration: Animations.normal } }
    Behavior on border.color { ColorAnimation { duration: Animations.normal } }
}
