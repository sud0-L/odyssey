import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

FocusScope {
    id: root

    // No action is armed when the page opens. This prevents the key release
    // that invoked the surface from activating Lock or Suspend immediately.
    property int currentIndex: -1
    property bool confirmationVisible: false
    property string confirmationAction: ""
    property int confirmationChoice: 0

    readonly property var actions: [
        {
            action: "lock",
            title: "Lock",
            detail: "Secure this session",
            icon: "󰌾",
            available: SessionService.lockAvailable,
            confirmation: false,
            destructive: false
        },
        {
            action: "suspend",
            title: "Suspend",
            detail: "Sleep in memory",
            icon: "󰒲",
            available: SessionService.suspendAvailable,
            confirmation: false,
            destructive: false
        },
        {
            action: "hibernate",
            title: "Hibernate",
            detail: "Save session to disk",
            icon: "󰤄",
            available: SessionService.hibernateAvailable,
            confirmation: true,
            destructive: false
        },
        {
            action: "logout",
            title: "Log out",
            detail: "End the Hyprland session",
            icon: "󰍃",
            available: SessionService.logoutAvailable,
            confirmation: true,
            destructive: false
        },
        {
            action: "reboot",
            title: "Restart",
            detail: "Restart this computer",
            icon: "󰜉",
            available: SessionService.rebootAvailable,
            confirmation: true,
            destructive: false
        },
        {
            action: "shutdown",
            title: "Shut down",
            detail: "Power off this computer",
            icon: "󰐥",
            available: SessionService.shutdownAvailable,
            confirmation: true,
            destructive: true
        }
    ]

    readonly property var pendingDetails: {
        for (const entry of actions) {
            if (entry.action === confirmationAction)
                return entry
        }
        return ({ title: "", action: "", icon: "", destructive: false })
    }

    signal dismissRequested()

    function cancelConfirmation(): bool {
        if (!confirmationVisible)
            return false
        confirmationVisible = false
        confirmationAction = ""
        confirmationChoice = 0
        return true
    }

    function requestAction(index: int): void {
        const entry = actions[index]
        if (!entry || !entry.available || SessionService.executing)
            return
        currentIndex = index
        if (entry.confirmation) {
            confirmationAction = entry.action
            confirmationChoice = 0
            confirmationVisible = true
            return
        }
        if (SessionService.schedule(entry.action))
            dismissRequested()
    }

    function finishConfirmation(): void {
        if (confirmationChoice === 0) {
            cancelConfirmation()
            return
        }
        const action = confirmationAction
        if (SessionService.schedule(action)) {
            confirmationVisible = false
            dismissRequested()
        }
    }

    function chooseConfirmation(confirm: bool): void {
        if (confirm) {
            confirmationChoice = 1
            finishConfirmation()
        } else {
            cancelConfirmation()
        }
    }

    function moveSelection(horizontal: int, vertical: int): void {
        if (currentIndex < 0) {
            currentIndex = 0
            return
        }
        const columns = 3
        const row = Math.floor(currentIndex / columns)
        const column = currentIndex % columns
        const nextRow = Math.max(0, Math.min(1, row + vertical))
        const nextColumn = Math.max(0, Math.min(columns - 1, column + horizontal))
        currentIndex = nextRow * columns + nextColumn
    }

    onVisibleChanged: {
        if (visible) {
            currentIndex = -1
            confirmationVisible = false
            confirmationAction = ""
            confirmationChoice = 0
            SessionService.refresh()
            Qt.callLater(() => root.forceActiveFocus())
        }
    }

    Keys.onPressed: event => {
        if (confirmationVisible) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                    || event.key === Qt.Key_Tab) {
                confirmationChoice = confirmationChoice === 0 ? 1 : 0
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                finishConfirmation()
                event.accepted = true
            }
            return
        }

        if (event.key === Qt.Key_Left) {
            moveSelection(-1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            moveSelection(1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            moveSelection(0, -1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            moveSelection(0, 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            currentIndex = 0
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            currentIndex = actions.length - 1
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            requestAction(currentIndex)
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space4

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space3

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Session"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Secure, pause, or end this session"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: Theme.space3
            rowSpacing: Theme.space3

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.currentIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusLarge
                    opacity: modelData.available ? 1 : 0.42
                    color: selected || actionHover.hovered
                        ? Theme.surfaceContainerHigh
                        : Qt.alpha(Theme.surfaceContainer, 0.74)
                    border.width: 1
                    border.color: selected
                        ? Qt.alpha(modelData.destructive ? Theme.error : Theme.primary, 0.62)
                        : Qt.alpha(Theme.outlineVariant, 0.44)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space2

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: Theme.radiusMedium
                            color: Qt.alpha(modelData.destructive
                                ? Theme.error : Theme.primary,
                                Theme.dark ? 0.16 : 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: modelData.destructive
                                    ? Theme.error : Theme.primary
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: Theme.iconMedium
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textBody
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.available ? modelData.detail : "Unavailable"
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textSmall
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: actionHover
                        enabled: modelData.available
                        onHoveredChanged: {
                            if (hovered)
                                root.currentIndex = index
                        }
                    }
                    TapHandler {
                        enabled: modelData.available && !root.confirmationVisible
                        onTapped: root.requestAction(index)
                    }

                    Behavior on color {
                        ColorAnimation { duration: Animations.fast }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: Animations.fast }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.confirmationVisible
        opacity: visible ? 1 : 0
        radius: Theme.radiusLarge
        color: Qt.alpha(Theme.surfaceContainerLow, 0.98)

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.space5 * 2, 430)
            spacing: Theme.space4

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 28
                color: Qt.alpha(root.pendingDetails.destructive
                    ? Theme.error : Theme.warning, Theme.dark ? 0.18 : 0.12)
                Text {
                    anchors.centerIn: parent
                    text: root.pendingDetails.icon
                    color: root.pendingDetails.destructive
                        ? Theme.error : Theme.warning
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 24
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.pendingDetails.title + "?"
                color: Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textTitle
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.confirmationAction === "hibernate"
                    ? "Open applications will remain available when the computer resumes."
                    : root.confirmationAction === "logout"
                        ? "Open applications in this Hyprland session will be closed."
                        : root.confirmationAction === "reboot"
                            ? "Open applications will be closed before the computer restarts."
                            : "Open applications will be closed before the computer powers off."
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.space3

                Repeater {
                    model: [
                        { label: "Cancel", confirm: false },
                        { label: root.pendingDetails.title, confirm: true }
                    ]
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 42
                        radius: Theme.radiusMedium
                        color: root.confirmationChoice === index
                            ? (modelData.confirm
                                ? (root.pendingDetails.destructive
                                    ? Theme.error : Theme.warning)
                                : Theme.primaryContainer)
                            : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: root.confirmationChoice === index
                            ? Qt.alpha(Theme.surfaceText, 0.42)
                            : Qt.alpha(Theme.outlineVariant, 0.42)
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.confirmationChoice === index
                                ? (modelData.confirm && root.pendingDetails.destructive
                                    ? Theme.primaryText
                                    : modelData.confirm ? Theme.surface
                                    : Theme.primaryContainerText)
                                : Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textBody
                            font.weight: Font.DemiBold
                        }
                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    root.confirmationChoice = index
                            }
                        }
                        TapHandler {
                            onTapped: root.chooseConfirmation(modelData.confirm)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "see you later."
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textSmall
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Animations.normal }
        }
    }
}
