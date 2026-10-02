import QtQuick
import "../core"

Item {
    id: root

    property url artworkSource: ""
    property bool active: false

    MediaArtwork {
        anchors.fill: parent
        artworkSource: root.artworkSource
        active: root.active
        atmospheric: true
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Animations.normal } }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.active
        color: Qt.alpha(Theme.surface, Theme.dark ? 0.58 : 0.66)
    }
    Rectangle {
        anchors.fill: parent
        visible: root.active
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.surface, 0.03) }
            GradientStop { position: 1; color: Qt.alpha(Theme.surface, 0.22) }
        }
    }
}
