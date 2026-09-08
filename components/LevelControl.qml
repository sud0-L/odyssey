import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string title: ""
    property string detail: ""
    property string icon: ""
    property real level: 0
    property bool available: true
    property bool actionActive: false
    property color accent: Theme.primary
    property bool expandable: false
    property bool expanded: false
    property real previewLevel: level
    property bool dragging: false
    property bool awaitingLevelConfirmation: false
    readonly property real displayedLevel: dragging || awaitingLevelConfirmation
        ? previewLevel
        : Math.max(0, Math.min(1, level))

    signal levelRequested(real level)
    signal actionRequested()
    signal detailsRequested()

    onLevelChanged: {
        if (!dragging && awaitingLevelConfirmation
                && Math.abs(level - previewLevel) <= 0.015) {
            awaitingLevelConfirmation = false
            levelConfirmationTimeout.stop()
        }
        if (!dragging && !awaitingLevelConfirmation)
            previewLevel = level
    }

    Timer {
        id: levelConfirmationTimeout
        interval: Config.controlCenter.levelConfirmationTimeout
        onTriggered: root.awaitingLevelConfirmation = false
    }

    activeFocusOnTab: available
    opacity: available ? 1 : 0.42
    radius: Theme.radiusMedium
    color: Qt.alpha(Theme.surfaceContainer, 0.78)
    border.width: 1
    border.color: activeFocus ? Qt.alpha(Theme.primary, 0.52)
        : Qt.alpha(Theme.outlineVariant, 0.48)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: Theme.space2

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: Theme.radiusSmall
            color: root.actionActive ? Qt.alpha(Theme.error, 0.20)
                : actionHover.hovered ? Theme.surfaceContainerHigh
                : Qt.alpha(root.accent, 0.14)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.actionActive ? Theme.error : root.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
            }

            HoverHandler { id: actionHover; enabled: root.available }
            TapHandler {
                enabled: root.available
                onTapped: root.actionRequested()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: Theme.space1

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.detail
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 9
                    }
                }

                Text {
                    text: Math.round(root.displayedLevel * 100) + "%"
                    color: root.accent
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: root.expandable
                    text: "󰅀"
                    color: root.expanded ? root.accent : Theme.surfaceVariantText
                    rotation: root.expanded ? 180 : 0
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 13

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Animations.normal
                            easing.type: Animations.emphasizedEase
                        }
                    }
                }

                TapHandler {
                    enabled: root.available && root.expandable
                    onTapped: root.detailsRequested()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: height / 2
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        width: parent.width * root.displayedLevel
                        height: parent.height
                        radius: parent.radius
                        color: root.accent

                        Behavior on width {
                            enabled: !root.dragging
                            NumberAnimation {
                                duration: Animations.fast
                                easing.type: Animations.standardEase
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.available
                    cursorShape: Qt.PointingHandCursor

                    function updatePreview(mouseX) {
                        root.previewLevel = Math.max(0,
                            Math.min(1, mouseX / width))
                    }

                    onPressed: mouse => {
                        levelConfirmationTimeout.stop()
                        root.awaitingLevelConfirmation = false
                        root.dragging = true
                        updatePreview(mouse.x)
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            updatePreview(mouse.x)
                    }
                    onReleased: mouse => {
                        updatePreview(mouse.x)
                        root.awaitingLevelConfirmation = true
                        root.dragging = false
                        levelConfirmationTimeout.restart()
                        root.levelRequested(root.previewLevel)
                    }
                    onCanceled: {
                        levelConfirmationTimeout.stop()
                        root.dragging = false
                        root.awaitingLevelConfirmation = false
                        root.previewLevel = root.level
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (!root.available)
            return
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.levelRequested(Math.max(0, root.level - 0.05))
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.levelRequested(Math.min(1, root.level + 0.05))
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            root.actionRequested()
            event.accepted = true
        }
    }

    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
