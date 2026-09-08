import QtQuick
import "../core"

QtObject {
    id: root

    readonly property string dormant: "dormant"
    readonly property string hover: "hover"
    readonly property string expanded: "expanded"
    readonly property string volume: "volume"
    readonly property string microphone: "microphone"
    readonly property string brightness: "brightness"
    readonly property string powerProfile: "powerProfile"
    readonly property string media: "media"
    readonly property string notification: "notification"
    readonly property string screenshot: "screenshot"

    property string logicalState: dormant
    property string transientState: ""
    property int transientPriority: 0
    property real transientLevel: 0
    property bool transientMuted: false
    property string transientDeviceName: ""
    property bool pointerInside: false
    // A transient click returns directly to the Auto Hide geometry. This is a
    // state transition, not a delayed/pointer-derived dismissal.
    property bool immediateHiddenTransition: false
    property bool notificationDismissing: false
    signal transientDismissAnimationFinished()
    property bool mediaVisible: false
    property bool recordingActive: false
    property bool fullscreen: false
    property string expandedPage: "overview"
    property real expandedDetailProgress: 0
    property bool expandedDetailTransitionActive: false
    property bool dismissing: false
    property string dismissTarget: dormant
    property bool autoHidden: false
    property bool autoHideEnabled: Config.island.autoHide
    property bool overlayWithoutReservation: false

    readonly property string visualState: transientState || logicalState
    readonly property bool transientActive: transientState !== ""
    readonly property bool revealOnly: (autoHidden || fullscreen)
        && visualState === dormant && !pointerInside && !dismissing
    readonly property bool expandedActive: logicalState === expanded && !dismissing
    readonly property bool expandedPresentationActive: logicalState === expanded || dismissing
    readonly property bool insightPage: expandedPage === "weather"
        || expandedPage === "calendar" || expandedPage === "media-center"
        || expandedPage === "system" || expandedPage === "battery"
    readonly property bool dashboardPage: expandedPage === "overview"
    readonly property bool wallpaperPage: expandedPage === "wallpaper"
        || expandedPage === "identity-image"
    readonly property bool clipboardPage: expandedPage === "clipboard"
    readonly property bool capturePage: expandedPage === "capture"
    readonly property bool sessionPage: expandedPage === "session"
    readonly property bool settingsPage: expandedPage === "settings"
    readonly property bool shouldShow: !fullscreen || !Config.island.hideInFullscreen
        || transientActive || recordingActive || dismissing
        || Config.island.autoHide || fullscreen

    readonly property int targetWidth: visualState === expanded
        ? (dashboardPage ? Config.dashboard.width
            : expandedPage === "notifications" ? Config.notifications.width
            : wallpaperPage ? Config.wallpaper.width
            : clipboardPage ? Config.clipboard.width
            : capturePage ? Config.capture.width
            : sessionPage ? Config.session.width
            : settingsPage ? Config.settings.width
            : insightPage ? Config.insights.width
            : expandedPage === "launcher" ? Config.launcher.width
            : Config.island.expandedWidth)
        : visualState === media ? Config.island.mediaWidth
        : visualState === notification ? Config.island.mediaWidth
        : transientActive ? Config.island.osdWidth
        : visualState === hover ? (mediaVisible
            ? Math.max(Config.island.hoverWidth,
                Config.island.hoverMediaMinimumWidth)
            : Math.max(Config.island.hoverWidth,
                Config.island.hoverMinimumWidth))
        : Math.max(Config.island.dormantWidth,
            Config.island.restMinimumWidth)
    readonly property int targetHeight: visualState === expanded
        ? (dashboardPage ? Config.dashboard.height
            : expandedPage === "notifications" ? Config.notifications.height
            : wallpaperPage ? Config.wallpaper.height
            : clipboardPage ? Config.clipboard.height
            : capturePage ? Config.capture.height
            : sessionPage ? Config.session.height
            : settingsPage ? Config.settings.height
            : insightPage ? Config.insights.height
            : expandedPage === "launcher" ? Config.launcher.height
            : expandedPage === "control-center"
                ? Math.round(Config.island.expandedHeight
                    + (Config.controlCenter.detailExpandedHeight
                        - Config.island.expandedHeight) * expandedDetailProgress)
                : Config.island.expandedHeight)
        : visualState === media ? Config.island.mediaHeight
        : visualState === notification ? Config.island.mediaHeight
        : transientActive ? Config.island.osdHeight
        : visualState === hover ? Config.island.hoverHeight
        : Config.island.dormantHeight

    function statePriority(state): int {
        if (state === screenshot)
            return 55
        if (state === expanded)
            return 50
        if (state === notification)
            return 45
        if (state === volume || state === microphone || state === brightness
                || state === powerProfile)
            return 40
        if (state === media)
            return 30
        if (state === hover)
            return 20
        return 0
    }

    function enter(): void {
        collapseTimer.stop()
        pointerInside = true
        immediateHiddenTransition = false
        // Notification/transient overlays must remain outside the workspace
        // reservation when hovered. Only the hidden resting edge deliberately
        // converts a pointer reveal back into a workspace-reserving surface.
        showSurface(autoHidden || !overlayWithoutReservation)
        if (dismissing)
            return
        if (!expandedActive)
            logicalState = hover
    }

    function leave(): void {
        pointerInside = false
        if (!dismissing && logicalState === hover)
            collapseTimer.restart()
    }

    function cancelDismissal(): void {
        dismissContentTimer.stop()
        dismissSurfaceTimer.stop()
        dismissing = false
    }

    function showSurface(reserveWorkspace): void {
        autoHideTimer.stop()
        immediateHiddenTransition = false
        autoHidden = false
        overlayWithoutReservation = autoHideEnabled
            && reserveWorkspace === false
    }

    function scheduleAutoHide(): void {
        autoHideTimer.stop()
        if (autoHideEnabled && visualState === dormant && !pointerInside
                && !dismissing)
            autoHideTimer.restart()
    }

    function deactivateForMonitorPolicy(): void {
        collapseTimer.stop()
        dismissContentTimer.stop()
        dismissSurfaceTimer.stop()
        transientTimer.stop()
        transientState = ""
        transientPriority = 0
        pointerInside = false
        dismissing = false
        expandedPage = "overview"
        logicalState = dormant
        showSurface()
    }

    function toggleExpanded(): void {
        showSurface()
        const openNotificationCenter = visualState === notification
        collapseTimer.stop()
        clearTransient()
        if (expandedActive)
            dismiss()
        else {
            cancelDismissal()
            expandedPage = openNotificationCenter ? "notifications" : "overview"
            logicalState = expanded
        }
    }

    function openPage(page: string): void {
        showSurface()
        collapseTimer.stop()
        clearTransient()
        cancelDismissal()
        expandedPage = page
        logicalState = expanded
    }

    function closePage(page: string): void {
        if (expandedActive && expandedPage === page)
            dismiss()
    }

    function togglePage(page: string): void {
        if (expandedActive && expandedPage === page)
            dismiss()
        else
            openPage(page)
    }

    function collapse(): void {
        if (dismissing || logicalState !== hover)
            return
        logicalState = pointerInside ? hover : dormant
    }

    function dismiss(forceDormant): void {
        if (dismissing || logicalState !== expanded)
            return
        clearTransient()
        collapseTimer.stop()
        dismissTarget = forceDormant ? dormant
            : (pointerInside ? hover : dormant)
        // Fade the expanded presentation before shrinking its clipping surface.
        // Resting content enters only after the surface reaches its final size.
        dismissing = true
        dismissContentTimer.restart()
    }

    function settle(): void {
        if (pointerInside || expandedActive)
            return
        logicalState = dormant
    }

    function requestTransient(state, level, muted, deviceName, priority,
            duration, reserveWorkspace): void {
        if (priority < statePriority(logicalState) || priority < transientPriority)
            return

        const directTransientOverlay = autoHideEnabled
            && reserveWorkspace === false
        // A non-reserving transient is an overlay, not a brief restoration of
        // the hidden resting island. Set its state before revealing the surface
        // so the dormant presentation never participates in this transition.
        if (directTransientOverlay)
            overlayWithoutReservation = true
        else
            showSurface(reserveWorkspace)
        transientState = state
        transientLevel = Math.max(0, Math.min(1, level))
        transientMuted = muted
        transientDeviceName = deviceName
        transientPriority = priority
        transientTimer.interval = duration
        transientTimer.restart()
        if (directTransientOverlay)
            showSurface(reserveWorkspace)
    }

    function showVolume(level, muted, deviceName): void {
        requestTransient(volume, level, muted, deviceName, 40,
            Config.island.osdTimeout, false)
    }

    function showMicrophone(level, muted, deviceName): void {
        requestTransient(microphone, level, muted, deviceName, 40,
            Config.island.osdTimeout, false)
    }

    function showBrightness(level, deviceName): void {
        requestTransient(brightness, level, false, deviceName, 40,
            Config.island.osdTimeout, false)
    }

    function showPowerProfile(level, profileName): void {
        requestTransient(powerProfile, level, false, profileName, 40,
            Config.island.osdTimeout, false)
    }

    function showMedia(): void {
        requestTransient(media, 0, false, "", 30,
            Config.media.presentationTimeout, false)
    }

    function showNotification(critical: bool): void {
        requestTransient(notification, 0, false, "", critical ? 70 : 45,
            critical ? Config.notifications.criticalTimeout
                : Config.notifications.timeout, false)
    }

    function showCaptureFeedback(): void {
        requestTransient(screenshot, 0, false, "", 55,
            Config.capture.completionTimeout, false)
    }

    function clearTransient(): void {
        const returnDirectlyToAutoHide = autoHideEnabled
            && overlayWithoutReservation && transientState !== ""
            && !pointerInside && !dismissing
        transientTimer.stop()
        if (returnDirectlyToAutoHide) {
            immediateHiddenTransition = true
            autoHidden = true
        }
        transientState = ""
        transientPriority = 0
        scheduleAutoHide()
    }

    function expireTransientNotification(): void {
        // Use the same visual dismissal phase as a click. It keeps the overlay
        // alive for the existing reverse opacity transition, then resolves
        // directly to hidden without exposing the resting island.
        if (notificationDismissing)
            return
        if (visualState !== notification) {
            clearTransient()
            return
        }
        dismissTransientNotification()
    }

    function dismissTransientNotification(): void {
        if (visualState !== notification || notificationDismissing)
            return
        notificationDismissing = true
        notificationDismissTimer.restart()
    }

    function finishTransientNotificationDismiss(): void {
        notificationDismissing = false
        collapseTimer.stop()
        logicalState = dormant
        if (autoHideEnabled) {
            // A click originated inside the temporary overlay, not the resting
            // Island. Restore the hidden state synchronously instead of waiting
            // for a pointer-leave event that may happen after focus changes.
            pointerInside = false
            immediateHiddenTransition = true
            autoHidden = true
        }
        clearTransient()
        transientDismissAnimationFinished()
    }

    onVisualStateChanged: {
        if (visualState === dormant)
            scheduleAutoHide()
        else
            showSurface(!overlayWithoutReservation)
    }

    onAutoHideEnabledChanged: {
        if (autoHideEnabled)
            scheduleAutoHide()
        else {
            immediateHiddenTransition = false
            showSurface()
        }
    }

    property Timer collapseTimer: Timer {
        interval: Config.island.collapseDelay
        onTriggered: root.collapse()
    }

    property Timer notificationDismissTimer: Timer {
        interval: Animations.fast
        repeat: false
        onTriggered: root.finishTransientNotificationDismiss()
    }

    property Timer dismissContentTimer: Timer {
        interval: Animations.fast
        onTriggered: {
            root.logicalState = root.dismissTarget
            root.dismissSurfaceTimer.restart()
        }
    }

    property Timer dismissSurfaceTimer: Timer {
        interval: Config.animations.surfaceMorph
        onTriggered: {
            root.dismissing = false
            // Pointer state can change while the expanded surface shrinks.
            // Never retain hover when the pointer is outside its final geometry.
            if (root.logicalState === root.hover && !root.pointerInside)
                root.logicalState = root.dormant
            root.scheduleAutoHide()
        }
    }

    property Timer transientTimer: Timer {
        interval: Config.island.osdTimeout
        onTriggered: {
            if (root.transientState === root.notification)
                root.expireTransientNotification()
            else
                root.clearTransient()
        }
    }

    property Timer autoHideTimer: Timer {
        interval: Config.island.autoHideDelay
        onTriggered: {
            if (root.autoHideEnabled && root.visualState === root.dormant
                    && !root.pointerInside && !root.dismissing)
                root.autoHidden = true
        }
    }

    Component.onCompleted: {
        settle()
        scheduleAutoHide()
    }
}
