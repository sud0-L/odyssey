import QtQuick
import QtQuick.Layouts
import "../core"

RowLayout {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property string suffix: ""
    property bool available: true
    signal adjusted(real value)

    enabled: available
    opacity: available ? 1 : 0.38
    spacing: Theme.space1
    implicitWidth: 122
    implicitHeight: 26

    function bounded(nextValue: real): real {
        const stepped = Math.round(nextValue / stepSize) * stepSize
        return Math.max(from, Math.min(to, stepped))
    }

    TextButton {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        compact: true
        text: "−"
        enabled: root.available && root.value > root.from
        opacity: enabled ? 1 : 0.36
        onClicked: root.adjusted(root.bounded(root.value - root.stepSize))
    }

    Rectangle {
        Layout.preferredWidth: 62
        Layout.preferredHeight: 26
        radius: Theme.radiusSmall
        color: valueInput.activeFocus
            ? Qt.alpha(Theme.primaryContainer, 0.42)
            : Qt.alpha(Theme.surfaceContainerHigh, 0.72)
        border.width: 1
        border.color: valueInput.activeFocus
            ? Theme.primary : Qt.alpha(Theme.outlineVariant, 0.54)

        RowLayout {
            anchors.centerIn: parent
            spacing: root.suffix === "%" ? 0 : 3

            TextInput {
                id: valueInput
                property bool cancelEdit: false
                Layout.preferredWidth: Math.max(12, implicitWidth)
                color: Theme.primary
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.primaryContainerText
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator {
                    regularExpression: /[0-9]{0,9}/
                }
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold

                function restoreValue(): void {
                    text = Math.round(root.value).toString()
                }

                function commitValue(): void {
                    const nextValue = Number(text)
                    if (text.length > 0 && Number.isFinite(nextValue)) {
                        const nextBounded = root.bounded(nextValue)
                        root.adjusted(nextBounded)
                        text = Math.round(nextBounded).toString()
                    } else {
                        restoreValue()
                    }
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll()
                    else if (cancelEdit) {
                        cancelEdit = false
                        restoreValue()
                    } else {
                        commitValue()
                    }
                }
                onAccepted: focus = false
                Keys.onEscapePressed: event => {
                    cancelEdit = true
                    focus = false
                    event.accepted = true
                }
                Component.onCompleted: restoreValue()
            }

            Text {
                visible: root.suffix.length > 0
                text: root.suffix
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }

        TapHandler {
            onTapped: valueInput.forceActiveFocus()
        }

        Connections {
            target: root
            function onValueChanged(): void {
                if (!valueInput.activeFocus)
                    valueInput.restoreValue()
            }
        }

        Behavior on color { ColorAnimation { duration: Animations.fast } }
        Behavior on border.color { ColorAnimation { duration: Animations.fast } }
    }

    TextButton {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        compact: true
        text: "+"
        enabled: root.available && root.value < root.to
        opacity: enabled ? 1 : 0.36
        onClicked: root.adjusted(root.bounded(root.value + root.stepSize))
    }
}
