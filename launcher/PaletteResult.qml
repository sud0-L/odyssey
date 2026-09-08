import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

Rectangle {
    id: root

    required property var result
    property bool selected: false
    signal activated()
    signal pointed()

    readonly property color resultAccent: result.kind === "workspace"
        ? Theme.tertiary : Theme.primary

    implicitHeight: 58
    radius: Theme.radiusMedium
    color: selected ? Theme.primaryContainer
        : resultHover.hovered ? Theme.surfaceContainerHigh : "transparent"
    opacity: result.enabled ? 1 : 0.46

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space3
        spacing: Theme.space3

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.radiusSmall
            color: root.selected ? Qt.alpha(root.resultAccent, 0.18)
                : Theme.surfaceContainerHigh

            Image {
                id: themedIcon
                anchors.fill: parent
                anchors.margins: 7
                visible: root.result.iconKind === "theme"
                source: visible && root.result.icon
                    ? Quickshell.iconPath(root.result.icon, true) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.result.iconKind === "glyph"
                    || themedIcon.status !== Image.Ready
                text: root.result.iconKind === "glyph"
                    ? root.result.icon : "󰣆"
                color: root.selected
                    ? root.resultAccent : Theme.surfaceVariantText
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.result.title
                color: root.selected
                    ? Theme.primaryContainerText : Theme.surfaceText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textSmall
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.result.subtitle
                color: root.selected
                    ? Qt.alpha(Theme.primaryContainerText, 0.72)
                    : Theme.surfaceVariantText
                elide: Text.ElideRight
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }
        }

        Text {
            text: root.result.badge
            color: root.selected
                ? Qt.alpha(Theme.primaryContainerText, 0.72)
                : Theme.surfaceVariantText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 9
        }

        Text {
            visible: root.selected && root.result.enabled
                && root.result.executable !== false
            text: "↵"
            color: Theme.primaryContainerText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Theme.textBody
        }
    }

    HoverHandler {
        id: resultHover
        enabled: root.result.enabled
        onHoveredChanged: {
            if (hovered)
                root.pointed()
        }
    }
    TapHandler {
        enabled: root.result.enabled && root.result.executable !== false
        onTapped: root.activated()
    }

    Behavior on color {
        ColorAnimation {
            duration: Animations.fast
            easing.type: Animations.emphasizedEase
        }
    }
}
