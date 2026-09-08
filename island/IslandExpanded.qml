import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../panels"
import "../launcher"
import "../services"

Item {
    id: root
    property var monitor
    property string page: "overview"
    property bool active: false
    property alias settingsSection: settingsPage.section
    readonly property bool overviewOpen: page === "overview"
    readonly property bool launcherOpen: page === "launcher"
    readonly property bool notificationsOpen: page === "notifications"
    readonly property bool clipboardOpen: page === "clipboard"
    readonly property bool captureOpen: page === "capture"
    readonly property bool sessionOpen: page === "session"
    readonly property bool settingsOpen: page === "settings"
    readonly property bool settingsLivePreviewActive: active && settingsOpen
        && settingsPage.livePreviewActive
    readonly property string settingsPreviewMode: settingsPage.pillPreviewMode
    readonly property bool controlCenterOpen: page === "control-center"
    readonly property bool wallpaperOpen: page === "wallpaper"
    readonly property bool identityPickerOpen: page === "identity-image"
    property string identityReturnPage: "overview"
    readonly property bool insightOpen: page === "weather" || page === "calendar"
        || page === "media-center" || page === "system" || page === "battery"
    readonly property bool controlCenterDetailOpen:
        controlCenterOpen && controlCenter.detailOpen
    readonly property real controlCenterDetailProgress:
        controlCenterOpen ? controlCenter.detailProgress : 0
    readonly property bool controlCenterDetailTransitionActive:
        controlCenterOpen && controlCenter.detailTransitionActive
    signal pageSelected(string selectedPage)
    signal dismissRequested(bool forceDormant)

    function openIdentityPicker(): void {
        if (identityPickerOpen) {
            pageSelected(identityReturnPage)
            return
        }
        identityReturnPage = page
        pageSelected("identity-image")
    }

    function closeIdentityPicker(): void {
        pageSelected(identityReturnPage)
    }

    function closeTransientUi(): bool {
        if (sessionOpen && sessionPage.cancelConfirmation())
            return true
        if (identityPickerOpen) {
            closeIdentityPicker()
            return true
        }
        if (controlCenterOpen)
            return controlCenter.closeExpandedSection()
        return false
    }

    onActiveChanged: {
        if (active)
            inactiveCleanup.stop()
        else {
            inactiveCleanup.restart()
            settingsPage.islandEditor = "overview"
        }
    }

    Timer {
        id: inactiveCleanup
        interval: Config.animations.surfaceMorph + Animations.fast
        onTriggered: controlCenter.resetDetails()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.maximumHeight: 30
            spacing: Theme.space2

            PersonalLogo {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                imageMargin: 2
                onEditRequested: root.openIdentityPicker()
            }
            Rectangle {
                id: profileButton
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: profileNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: PowerProfileService.icon
                    color: PowerProfileService.profileId === "performance"
                        ? Theme.tertiary : Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: profileNavHover }
                TapHandler {
                    onTapped: root.pageSelected("control-center")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.sessionOpen ? Theme.primaryContainer
                    : sessionNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    color: root.sessionOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: sessionNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.sessionOpen
                        ? "overview" : "session")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.wallpaperOpen ? Theme.primaryContainer
                    : wallpaperNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰸉"
                    color: root.wallpaperOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: wallpaperNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.wallpaperOpen
                        ? "overview" : "wallpaper")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.captureOpen ? Theme.primaryContainer
                    : captureNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: CaptureService.recording ? "󰑊" : "󰄀"
                    color: CaptureService.recording ? Theme.error
                        : root.captureOpen ? Theme.primaryContainerText
                        : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: captureNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.captureOpen
                        ? "overview" : "capture")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.controlCenterOpen ? Theme.primaryContainer
                    : controlsNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.controlCenterOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: controlsNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.controlCenterOpen
                        ? "overview" : "control-center")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.clipboardOpen ? Theme.primaryContainer
                    : clipboardNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅌"
                    color: root.clipboardOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: clipboardNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.clipboardOpen
                        ? "overview" : "clipboard")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.insightOpen ? Theme.primaryContainer
                    : insightsNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰕮"
                    color: root.insightOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: insightsNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.insightOpen ? "overview" : "weather")
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.launcherOpen ? Theme.primaryContainer
                    : launcherNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰀻"
                    color: root.launcherOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: launcherNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.launcherOpen
                        ? "overview" : "launcher")
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.settingsOpen ? Theme.primaryContainer
                    : settingsNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰒓"
                    color: root.settingsOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                HoverHandler { id: settingsNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.settingsOpen
                        ? "overview" : "settings")
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.radiusSmall
                color: root.notificationsOpen ? Theme.primaryContainer
                    : notificationNavHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                    color: root.notificationsOpen
                        ? Theme.primaryContainerText : Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                Rectangle {
                    visible: NotificationService.count > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: NotificationService.count > 9 ? 20 : 14
                    height: 14
                    radius: 7
                    color: Theme.error

                    Text {
                        anchors.centerIn: parent
                        text: NotificationService.count > 99 ? "99+"
                            : NotificationService.count.toString()
                        color: Theme.primaryText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }

                HoverHandler { id: notificationNavHover }
                TapHandler {
                    onTapped: root.pageSelected(root.notificationsOpen
                        ? "overview" : "notifications")
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                Layout.preferredHeight: 30
                spacing: Theme.space2

                Rectangle {
                    id: caffeineButton
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: IdleService.inhibited
                        ? Qt.alpha(Theme.error, 0.16)
                        : caffeineHover.hovered
                            ? Theme.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        text: "󰅶"
                        color: IdleService.inhibited
                            ? Theme.error : Theme.surfaceText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall
                    }

                    HoverHandler { id: caffeineHover }
                    TapHandler { onTapped: IdleService.toggleInhibition() }

                    Behavior on color {
                        ColorAnimation { duration: Animations.fast }
                    }
                }

                RowLayout {
                    visible: BatteryService.available
                    Layout.fillHeight: true
                    spacing: Theme.space1

                    Text {
                        text: BatteryService.icon
                        color: BatteryService.percentageInt <= 15
                            ? Theme.error : BatteryService.charging
                                ? Theme.success : Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.textBody
                        font.weight: Font.Bold
                    }
                    Text {
                        text: BatteryService.percentageInt + "%"
                        color: Theme.surfaceText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.textBody
                        font.weight: Font.Bold
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: ShellState.time
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.textBody
                    font.weight: Font.Bold
                }
            }
        }

        NotificationCenter {
            visible: root.notificationsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ClipboardPage {
            visible: root.clipboardOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        CapturePage {
            visible: root.captureOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            monitor: root.monitor
            onDismissRequested: forceDormant =>
                root.dismissRequested(forceDormant)
        }

        SessionPage {
            id: sessionPage
            visible: root.sessionOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            onDismissRequested: root.dismissRequested(false)
        }

        SettingsPage {
            id: settingsPage
            visible: root.settingsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            monitor: root.monitor
        }

        Dashboard {
            visible: root.overviewOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            onPageRequested: page => root.pageSelected(page)
        }

        ControlCenter {
            id: controlCenter
            visible: root.controlCenterOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ApplicationLauncher {
            visible: root.launcherOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            onDismissRequested: root.dismissRequested(false)
            onPageRequested: page => root.pageSelected(page)
        }

        InsightCenter {
            visible: root.insightOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            selectedPage: root.page
            onPageRequested: page => root.pageSelected(page)
            onPersonalImageRequested: root.openIdentityPicker()
        }

        WallpaperPage {
            visible: root.wallpaperOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            monitor: root.monitor
        }

        WallpaperPage {
            visible: root.identityPickerOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            monitor: root.monitor
            selectionMode: true
            onSelectionCompleted: root.closeIdentityPicker()
            onCancelRequested: root.closeIdentityPicker()
        }
    }

}
