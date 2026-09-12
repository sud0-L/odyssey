import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: window

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool monitorEnabled:
        HyprlandService.islandEnabledFor(monitor)
    readonly property bool presentationTarget:
        HyprlandService.shouldPresentOn(monitor)

    IslandController {
        id: islandController
        // Workspace-fill continues to use the normal resting/auto-hide flow.
        // Only true fullscreen suppresses the lip and uses the invisible edge.
        fullscreen: HyprlandService.trueFullscreenOn(
            window.monitor?.activeWorkspace)
        mediaVisible: MediaService.hoverVisible && Config.island.hoverShowMedia
        recordingActive: CaptureService.recording
        expandedDetailProgress: expandedContent.controlCenterDetailProgress
        expandedDetailTransitionActive:
            expandedContent.controlCenterDetailTransitionActive
    }

    HyprlandFocusGrab {
        windows: [window]
        active: islandController.expandedActive
        onCleared: islandController.dismiss()
    }

    IdleInhibitor {
        window: window
        enabled: IdleService.inhibited
    }


    anchors.top: true
    // A hidden surface must be hosted at the physical edge. A negative child
    // coordinate cannot reveal pixels above a PanelWindow that itself starts
    // below the configured top margin.
    margins.top: islandController.revealOnly ? 0 : Config.island.topMargin
    readonly property bool liveEditActive:
        expandedContent.settingsLivePreviewActive
    readonly property string liveEditMode: expandedContent.settingsPreviewMode
    readonly property int liveEditPreviewHeight: liveEditMode === "hover"
        ? Config.island.hoverHeight : Config.island.dormantHeight
    readonly property int liveEditOffset: liveEditActive
        ? liveEditPreviewHeight + Theme.space3 : 0
    implicitWidth: Math.max(Config.island.expandedWidth, Config.launcher.width,
        Config.island.restMinimumWidth, Config.island.hoverMinimumWidth,
        Config.island.hoverMediaMinimumWidth)
    implicitHeight: Math.max(Config.island.expandedHeight, Config.launcher.height,
        Config.controlCenter.detailExpandedHeight, Config.insights.height,
        Config.dashboard.height, Config.session.height, Config.settings.height)
        + liveEditOffset
    color: "transparent"
    visible: monitorEnabled && islandController.shouldShow
    mask: Region {
        item: islandController.revealOnly ? revealTarget : surface
    }
    exclusiveZone: monitorEnabled
            && !islandController.revealOnly
            && !(Config.island.autoHide
                && islandController.overlayWithoutReservation)
        ? Config.island.reservedSpace : 0

    WlrLayershell.namespace: "odyssey:island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: islandController.expandedActive
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onMonitorEnabledChanged: {
        if (!monitorEnabled)
            islandController.deactivateForMonitorPolicy()
    }

    Surface {
        id: surface
        property real powerPulse: 0
        property color powerPulseColor: Theme.success
        readonly property bool dormantPresentation:
            islandController.visualState === islandController.dormant

        x: Math.round((parent.width - width) / 2)
        y: liveEditActive ? liveEditOffset
            : islandController.revealOnly
                // The hidden reveal belongs to the display edge; normal top
                // margin is restored only after pointer reveal.
                ? -height
                : 0
        width: islandController.targetWidth
        height: islandController.targetHeight
        clip: true
        radius: Theme.radiusLarge
        color: Qt.tint(Qt.alpha(Theme.surfaceContainer, dormantPresentation
                ? 0.88 : Config.appearance.surfaceOpacity),
            Qt.alpha(powerPulseColor, powerPulse * 0.46))
        border.color: Qt.tint(Qt.alpha(Theme.outlineVariant, dormantPresentation
                ? (Theme.dark ? 0.38 : 0.32)
                : (Theme.dark ? 0.62 : 0.48)),
            Qt.alpha(powerPulseColor, powerPulse * 0.82))

        Behavior on width {
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }
        Behavior on height {
            enabled: !islandController.expandedDetailTransitionActive
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }

        Behavior on y {
            enabled: !islandController.immediateHiddenTransition
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }

        Behavior on radius {
            NumberAnimation { duration: Animations.normal; easing.type: Animations.standardEase }
        }

        FocusScope {
            id: contentFocus
            anchors.fill: parent
            focus: islandController.expandedActive
            Keys.onEscapePressed: {
                if (!expandedContent.closeTransientUi())
                    islandController.dismiss(true)
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(Config.island.dormantWidth,
                    Config.island.restMinimumWidth)
                height: Config.island.dormantHeight
                enabled: !islandController.dismissing
                    && islandController.visualState === islandController.dormant
                opacity: enabled ? 1 : 0
                IslandDormant {
                    id: dormantContent
                    anchors.fill: parent
                    onPowerRequested: islandController.openPage("control-center")
                    onCaptureRequested: islandController.openPage("capture")
                }
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: MediaService.hoverVisible
                    ? Math.max(Config.island.hoverWidth,
                        Config.island.hoverMediaMinimumWidth)
                    : Math.max(Config.island.hoverWidth,
                        Config.island.hoverMinimumWidth)
                height: Config.island.hoverHeight
                enabled: !islandController.dismissing
                    && islandController.visualState === islandController.hover
                opacity: enabled ? 1 : 0
                IslandHover {
                    anchors.fill: parent
                    monitor: window.monitor
                }
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                // Keep expanded content at stable final geometry while the
                // containing surface clips across its enter/exit morph.
                width: islandController.expandedPage === "launcher"
                    ? Config.launcher.width : islandController.dashboardPage
                        ? Config.dashboard.width : islandController.insightPage
                            ? Config.insights.width : islandController.sessionPage
                                ? Config.session.width : islandController.settingsPage
                                    ? Config.settings.width : Config.island.expandedWidth
                height: islandController.expandedPage === "launcher"
                    ? Config.launcher.height
                    : islandController.targetHeight
                enabled: islandController.expandedPresentationActive
                opacity: islandController.expandedActive ? 1 : 0
                IslandExpanded {
                    id: expandedContent
                    anchors.fill: parent
                    monitor: window.monitor
                    page: islandController.expandedPage
                    active: islandController.expandedActive
                    onPageSelected: selectedPage =>
                        islandController.expandedPage = selectedPage
                    onDismissRequested: forceDormant =>
                        islandController.dismiss(forceDormant)
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: islandController.dismissing
                            ? Animations.fast : Animations.normal
                    }
                }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.island.osdWidth
                height: Config.island.osdHeight
                enabled: islandController.transientActive
                    && islandController.visualState !== islandController.media
                    && islandController.visualState !== islandController.notification
                    && islandController.visualState !== islandController.screenshot
                opacity: enabled ? 1 : 0
                IslandOSD {
                    anchors.fill: parent
                    kind: islandController.transientState
                    level: islandController.transientLevel
                    muted: islandController.transientMuted
                    deviceName: islandController.transientDeviceName
                }
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.island.mediaWidth
                height: Config.island.mediaHeight
                enabled: islandController.visualState === islandController.media
                opacity: enabled ? 1 : 0
                IslandMedia { anchors.fill: parent }
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.island.mediaWidth
                height: Config.island.mediaHeight
                enabled: islandController.visualState === islandController.notification
                    && !islandController.notificationDismissing
                opacity: islandController.visualState === islandController.notification
                    && !islandController.notificationDismissing ? 1 : 0
                IslandNotification { anchors.fill: parent }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Animations.fast
                        easing.type: Animations.standardEase
                    }
                }
            }

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Config.island.osdWidth
                height: Config.island.osdHeight
                enabled: islandController.visualState === islandController.screenshot
                opacity: enabled ? 1 : 0
                IslandCaptureFeedback { anchors.fill: parent }
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
            }

        }

        HoverHandler {
            onHoveredChanged: hovered ? islandController.enter() : islandController.leave()
        }
        TapHandler {
            enabled: !islandController.expandedPresentationActive
                && islandController.visualState !== islandController.notification
                && !(islandController.visualState === islandController.dormant
                    && dormantContent.powerHovered)
            onTapped: islandController.toggleExpanded()
        }


        SequentialAnimation {
            id: powerConnectedPulse
            NumberAnimation {
                target: surface
                property: "powerPulse"
                from: 0
                to: 1
                duration: Config.animations.profileFeedbackRise
                easing.type: Easing.OutCubic
            }
            PauseAnimation {
                duration: Config.animations.profileFeedbackHold
            }
            NumberAnimation {
                target: surface
                property: "powerPulse"
                to: 0
                duration: Config.animations.profileFeedbackFade
                easing.type: Easing.OutQuart
            }
        }
    }

    // The target remains at the physical edge while hidden/fullscreen. The
    // visual lip is optional and is always suppressed over fullscreen content.
    Rectangle {
        id: revealTarget
        visible: islandController.revealOnly && !window.liveEditActive
        x: Math.round((parent.width - width) / 2)
        y: 0
        width: Math.max(Config.island.dormantWidth,
            Config.island.restMinimumWidth)
        height: Config.island.revealHeight
        color: "transparent"

        HoverHandler {
            onHoveredChanged: hovered ? islandController.enter()
                : islandController.leave()
        }

        Surface {
            id: revealStrip
            anchors.fill: parent
            visible: Config.island.showRevealLip && !islandController.fullscreen
            radius: height / 2
            color: Qt.alpha(Theme.surfaceContainer, 0.88)
            border.color: Qt.alpha(Theme.outlineVariant,
                Theme.dark ? 0.38 : 0.32)
        }
    }

    Surface {
        id: liveEditPreview
        visible: window.liveEditActive
        enabled: false
        x: Math.round((parent.width - width) / 2)
        y: 0
        width: window.liveEditMode === "hover"
            ? (MediaService.hoverVisible && Config.island.hoverShowMedia
                ? Math.max(Config.island.hoverWidth,
                    Config.island.hoverMediaMinimumWidth)
                : Math.max(Config.island.hoverWidth,
                    Config.island.hoverMinimumWidth))
            : Math.max(Config.island.dormantWidth,
                Config.island.restMinimumWidth)
        height: window.liveEditPreviewHeight
        radius: Theme.radiusLarge
        color: Qt.alpha(Theme.surfaceContainer,
            Config.appearance.surfaceOpacity)
        border.color: Qt.alpha(Theme.outlineVariant,
            Theme.dark ? 0.62 : 0.48)
        opacity: visible ? 1 : 0

        IslandDormant {
            anchors.fill: parent
            visible: window.liveEditMode === "rest"
        }
        IslandHover {
            anchors.fill: parent
            visible: window.liveEditMode === "hover"
            monitor: window.monitor
        }

        Behavior on width {
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }
        Behavior on opacity { NumberAnimation { duration: Animations.normal } }
    }

    Connections {
        target: islandController
        function onVisualStateChanged(): void {
            if (islandController.expandedActive)
                Qt.callLater(() => contentFocus.forceActiveFocus())
        }
    }

    Connections {
        target: islandController
        function onTransientDismissAnimationFinished(): void {
            if (window.presentationTarget)
                NotificationService.completeTransientDismiss()
        }
    }

    Connections {
        target: ShellActions
        function onLauncherToggleRequested(): void {
            if (window.presentationTarget)
                islandController.togglePage("launcher")
        }
        function onLauncherOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("launcher")
        }
        function onLauncherCloseRequested(): void {
            islandController.closePage("launcher")
        }
        function onCommandLauncherToggleRequested(): void {
            if (window.presentationTarget)
                islandController.togglePage("command-launcher")
        }
        function onCommandLauncherOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("command-launcher")
        }
        function onCommandLauncherCloseRequested(): void {
            islandController.closePage("command-launcher")
        }
        function onControlCenterToggleRequested(): void {
            if (window.presentationTarget)
                islandController.togglePage("control-center")
        }
        function onControlCenterOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("control-center")
        }
        function onControlCenterCloseRequested(): void {
            islandController.closePage("control-center")
        }
        function onClipboardToggleRequested(): void {
            if (window.presentationTarget)
                islandController.togglePage("clipboard")
        }
        function onClipboardOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("clipboard")
        }
        function onClipboardCloseRequested(): void {
            islandController.closePage("clipboard")
        }
        function onNotificationsToggleRequested(): void {
            if (window.presentationTarget)
                islandController.togglePage("notifications")
        }
        function onNotificationsOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("notifications")
        }
        function onNotificationsCloseRequested(): void {
            islandController.closePage("notifications")
        }
        function onCaptureOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("capture")
        }
        function onCaptureCloseRequested(): void {
            islandController.closePage("capture")
        }
        function onSessionOpenRequested(): void {
            if (window.presentationTarget)
                islandController.openPage("session")
        }
        function onSessionCloseRequested(): void {
            islandController.closePage("session")
        }
        function onSettingsOpenRequested(section): void {
            if (window.presentationTarget) {
                expandedContent.settingsSection = section || "appearance"
                islandController.openPage("settings")
            }
        }
        function onSettingsCloseRequested(): void {
            islandController.closePage("settings")
        }
        function onInsightOpenRequested(page): void {
            if (!window.presentationTarget)
                return
            if (page === "battery" && !BatteryService.available)
                islandController.openPage("weather")
            else
                islandController.openPage(page)
        }
    }

    Connections {
        target: CaptureService
        function onScreenshotFinished(success, path, copied): void {
            if (window.presentationTarget
                    && CaptureService.statusMessage !== "Screenshot cancelled")
                islandController.showCaptureFeedback()
        }
        function onRecordingFinished(success, path): void {
            if (window.presentationTarget
                    && !(islandController.expandedActive
                        && islandController.expandedPage === "capture"))
                islandController.showCaptureFeedback()
        }
    }

    Connections {
        target: AudioService
        function onOutputLevelChanged(level, muted, deviceName): void {
            if (window.presentationTarget)
                islandController.showVolume(level, muted, deviceName)
        }
        function onMicrophoneLevelChanged(level, muted, deviceName): void {
            if (window.presentationTarget)
                islandController.showMicrophone(level, muted, deviceName)
        }
    }

    Connections {
        target: BrightnessService
        function onBrightnessChanged(level, deviceName): void {
            if (window.presentationTarget)
                islandController.showBrightness(level, deviceName)
        }
    }

    Connections {
        target: PowerProfileService
        function onProfileSelected(level, profileName): void {
            if (window.presentationTarget)
                islandController.showPowerProfile(level, profileName)
        }
    }

    Connections {
        target: BatteryService
        function onPowerConnected(): void {
            if (window.presentationTarget) {
                surface.powerPulseColor = Theme.success
                powerConnectedPulse.restart()
            }
        }
        function onPowerDisconnected(): void {
            if (window.presentationTarget) {
                surface.powerPulseColor = Theme.error
                powerConnectedPulse.restart()
            }
        }
    }

    Connections {
        target: MediaService
        function onPresentationRequested(): void {
            if (Config.media.enabled && window.presentationTarget)
                islandController.showMedia()
        }
        function onPresentationDismissRequested(): void {
            if (islandController.visualState === islandController.media)
                islandController.clearTransient()
        }
    }

    Connections {
        target: NotificationService
        function onPresentationRequested(critical): void {
            if (window.presentationTarget)
                islandController.showNotification(critical)
        }
        function onPresentationDismissRequested(): void {
            if (islandController.visualState === islandController.notification)
                islandController.expireTransientNotification()
        }
        function onTransientDismissRequested(): void {
            islandController.dismissTransientNotification()
        }
        function onActivationCompleted(): void {
            if (islandController.visualState === islandController.notification)
                islandController.dismissTransientNotification()
            else if (islandController.expandedPage === "notifications")
                islandController.dismiss(true)
        }
    }
}
