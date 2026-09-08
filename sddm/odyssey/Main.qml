import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Effects 6.5
import SddmComponents 2.0

FocusScope {
    id: root

    width: parent ? parent.width : Screen.width
    height: parent ? parent.height : Screen.height
    property bool passwordVisible: false
    property string username: userModel.lastUser

    focus: true

    function revealPassword() {
        if (passwordVisible)
            return
        passwordVisible = true
        Qt.callLater(() => password.activate())
    }

    function submit() {
        if (password.text.length > 0) {
            password.authenticating = true
            sddm.login(username, password.text, sessionModel.lastIndex)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.BlankCursor
        z: 9999
    }

    Theme { id: theme }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: theme.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Image {
        id: currentWallpaper
        anchors.fill: parent
        source: theme.currentWallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: theme.surface
        z: -100
    }

    MultiEffect {
        anchors.fill: parent
        source: currentWallpaper.status === Image.Ready ? currentWallpaper : wallpaper
        blurEnabled: theme.blurEnabled
        blur: 1.0
        blurMax: theme.blurRadius
        visible: currentWallpaper.status === Image.Ready
            || wallpaper.status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: theme.dimmer
    }

    Text {
        id: welcome
        anchors.centerIn: parent
        text: "welcome."
        color: theme.text
        font.family: theme.monoFontFamily
        font.pixelSize: 18
        font.weight: Font.Medium
        opacity: root.passwordVisible ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }

    LockPasswordField {
        id: password
        anchors.centerIn: parent
        width: 460
        height: 56
        surfaceColor: theme.surfaceHigh
        outlineColor: theme.outline
        textColor: theme.text
        placeholderColor: theme.textMuted
        checkingColor: theme.primary
        failureColor: theme.error
        capsLockColor: theme.warning
        fontFamily: theme.monoFontFamily
        opacity: root.passwordVisible ? 1 : 0
        enabled: root.passwordVisible
        visible: opacity > 0
        onEmptyTimeout: root.passwordVisible = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submit()
                event.accepted = true
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            password.authenticating = false
            password.text = ""
            password.failed = true
            password.activate()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.revealPassword()
      }

    Keys.onPressed: event => {
        if (!root.passwordVisible) {
            root.revealPassword()
            event.accepted = true
        }
    }
}
