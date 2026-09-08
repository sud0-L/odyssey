import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    property string label: ""
    property string detail: ""
    property bool selected: false
    property bool available: true
    property bool compact: false
    property color accent: Theme.primary
    signal activated()

    activeFocusOnTab: available
    implicitWidth: choiceLabel.implicitWidth
        + (compact ? Theme.space3 * 2 : Theme.space4 * 2)
    implicitHeight: compact ? 30 : detail.length > 0 ? 52 : 34
    radius: Theme.radiusSmall
    opacity: available ? 1 : 0.42
    color: selected ? Qt.alpha(Theme.primaryContainer, 0.92)
        : hover.hovered || activeFocus ? Theme.surfaceContainerHigh
        : Qt.alpha(Theme.surfaceContainerHigh, 0.34)
    border.width: 1
    border.color: activeFocus ? Qt.alpha(accent, 0.82)
        : selected ? Qt.alpha(accent, 0.46) : "transparent"

    Keys.onReturnPressed: if (available) activated()
    Keys.onEnterPressed: if (available) activated()
    Keys.onSpacePressed: if (available) activated()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: 1

        Text {
            id: choiceLabel
            Layout.fillWidth: true
            text: root.label
            horizontalAlignment: Text.AlignHCenter
            color: root.selected ? Theme.primaryContainerText
                : Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            visible: root.detail.length > 0
            Layout.fillWidth: true
            text: root.detail
            horizontalAlignment: Text.AlignHCenter
            color: root.selected
                ? Qt.alpha(Theme.primaryContainerText, 0.76)
                : Theme.surfaceVariantText
            font.family: Config.appearance.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: hover; enabled: root.available }
    TapHandler {
        enabled: root.available
        onTapped: {
            root.forceActiveFocus()
            root.activated()
        }
    }
    Behavior on color { ColorAnimation { duration: Animations.fast } }
    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
}
