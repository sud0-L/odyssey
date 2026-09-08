import QtQuick 2.15

FocusScope {
    id: root

    property alias text: input.text
    property color surfaceColor: "#272a2f"
    property color outlineColor: "#42474e"
    property color textColor: "#e1e2e8"
    property color placeholderColor: "#c3c7cf"
    property color checkingColor: "#9fcafd"
    property color failureColor: "#ffb4ab"
    property color capsLockColor: "#f4c46b"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool authenticating: false
    property bool failed: false

    signal emptyTimeout()

    readonly property bool capsLock: keyboard.capsLock
    readonly property bool hasText: input.text.length > 0
    readonly property color activeOutline: failed ? failureColor
        : capsLock ? capsLockColor : activeFocus ? checkingColor : outlineColor
    readonly property string statusText: authenticating ? "authenticating…"
        : failed ? "failed." : capsLock ? "caps lock" : ""
    readonly property color statusColor: failed ? failureColor
        : capsLock ? capsLockColor : placeholderColor

    width: 360
    height: 56

    function resetFailure() {
        failed = false
    }

    function activate() {
        input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(
          root.surfaceColor.r,
          root.surfaceColor.g,
          root.surfaceColor.b,
          0.60
        )
        border.width: 0
        border.color: root.activeOutline

        Behavior on border.color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        focus: false
        color: "transparent"
        cursorVisible: false
        cursorDelegate: Item {
            width: 0
            height: 0
        }
        echoMode: TextInput.Password
        passwordCharacter: "●"
        font.family: root.fontFamily
        font.pixelSize: 18
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        onTextChanged: {
            root.authenticating = false
            root.resetFailure()
            emptyFade.restart()
        }
    }

    Text {
        id: dots
        anchors.centerIn: parent
        text: Array(input.text.length + 1).join("●")
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 3
        opacity: root.hasText && !root.statusText ? 1 : 0
        scale: root.hasText && !root.statusText ? 1 : 0.8

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.statusText || "..."
        color: root.statusText ? root.statusColor : root.placeholderColor
        font.family: root.fontFamily
        font.pixelSize: 14
        opacity: root.statusText ? 1
            : root.hasText ? 0 : emptyFade.placeholderOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }
    Timer {
        id: emptyFade
        interval: 3200
        repeat: false
        running: root.activeFocus && !root.hasText
        property real placeholderOpacity: 1
        onTriggered: root.emptyTimeout()
        onRunningChanged: if (running) placeholderOpacity = 1
    }
}
