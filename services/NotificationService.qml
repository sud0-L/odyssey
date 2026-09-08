pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../core"

Singleton {
    id: root

    readonly property bool serverEnabled: Config.notifications.enabled
        && Config.notifications.takeOverServer
    readonly property bool coexistenceMode: Config.notifications.enabled
        && !Config.notifications.takeOverServer
    readonly property bool doNotDisturb: Config.notifications.doNotDisturb
    property var history: []
    property var current: null
    // The D-Bus reply can reach the observer just before Quickshell delivers
    // the matching Notification object. Keep only a short, bounded in-memory
    // handoff so that ordering race does not discard exact provenance.
    property var pendingProvenance: ({})
    property var pendingExactFocus: null
    property var pendingTransientDismiss: null
    property bool provenanceRestartPending: false
    readonly property string provenanceHelperPath:
        Quickshell.shellDir + "/scripts/notification-provenance.py"

    readonly property int count: history.length
    readonly property bool hasCurrent: current !== null
    readonly property bool currentCritical: current?.critical ?? false

    signal presentationRequested(bool critical)
    signal presentationDismissRequested()
    // Emitted before removal so a transient click can tear down its overlay
    // before the generic current-cleared signal exposes any hover state.
    signal transientDismissRequested()
    signal activationCompleted()

    function plainText(value: string): string {
        return (value || "")
            .replace(/<img\b[^>]*>/gi, "")
            .replace(/<br\s*\/?>/gi, " ")
            .replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .trim()
    }

    function receive(notification: Notification): void {
        if (!notification)
            return

        notification.tracked = true
        const entry = {
            id: notification.id,
            source: notification,
            appName: notification.appName || "Application",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            title: plainText(notification.summary) || "Notification",
            body: plainText(notification.body),
            urgency: notification.urgency,
            critical: notification.urgency === NotificationUrgency.Critical,
            timestamp: Date.now(),
            // Preserve unlabeled `default` actions: many applications use
            // those specifically for clicking the notification body.
            actions: (notification.actions || []).filter(action => !!action),
            provenance: takePendingProvenance(notification.id),
            active: true
        }

        history = [entry].concat(history.filter(existing => existing.id !== entry.id))
            .slice(0, Config.notifications.historyLimit)
        notification.closed.connect(reason => markClosed(entry.id, entry.timestamp))

        const shouldPresent = entry.critical
            ? Config.notifications.allowCriticalAlerts
            : Config.notifications.showPopups && !doNotDisturb
        if (shouldPresent) {
            current = entry
            presentationRequested(entry.critical)
        }
    }

    function markClosed(id: int, timestamp: double): void {
        history = history.map(entry => {
            if (entry.id !== id || entry.timestamp !== timestamp)
                return entry
            return Object.assign({}, entry, { active: false, source: null, actions: [] })
        })
        if (current?.id === id && current?.timestamp === timestamp) {
            current = null
            presentationDismissRequested()
        }
    }

    function dismiss(entry): void {
        if (!entry)
            return
        if (entry.source)
            entry.source.dismiss()
        markClosed(entry.id, entry.timestamp)
    }

    function dismissCurrent(): void {
        dismiss(current)
    }

    function invokePrimaryAction(): void {
        activate(current)
    }

    function visibleActions(entry): var {
        return (entry?.actions || []).filter(action =>
            plainText(action?.text || "").length > 0)
    }

    function takePendingProvenance(notificationId): var {
        const key = String(notificationId)
        const pending = pendingProvenance[key]
        if (!pending)
            return null
        const updated = Object.assign({}, pendingProvenance)
        delete updated[key]
        pendingProvenance = updated
        return Date.now() - pending.timestamp <= 2000 ? pending.provenance : null
    }

    function cachePendingProvenance(notificationId, provenance): void {
        const key = String(notificationId)
        const updated = Object.assign({}, pendingProvenance)
        updated[key] = { provenance: provenance, timestamp: Date.now() }
        const keys = Object.keys(updated).sort((left, right) =>
            updated[left].timestamp - updated[right].timestamp)
        while (keys.length > 32)
            delete updated[keys.shift()]
        pendingProvenance = updated
    }

    function queueExactFocus(provenance): void {
        pendingExactFocus = provenance
        exactFocusTimer.restart()
    }

    function canActivate(entry): bool {
        if (!entry)
            return false
        if ((entry.actions || []).some(action => action?.identifier === "default"))
            return true
        return HyprlandService.hasValidExactProvenance(entry.provenance)
    }

    function activate(entry): bool {
        if (!entry)
            return false
        // When we have an exact live origin, release the expanded Island focus
        // grab first, then focus that verified window. A producer default action
        // is retained for entries without exact provenance.
        if (HyprlandService.hasValidExactProvenance(entry.provenance)) {
            requestTransientDismiss(entry)
            activationCompleted()
            queueExactFocus(entry.provenance)
            return true
        }
        const defaultAction = (entry.actions || []).find(action =>
            action?.identifier === "default")
        if (defaultAction) {
            defaultAction.invoke()
            requestTransientDismiss(entry)
            activationCompleted()
            return true
        }
        // Freedesktop metadata identifies an application, not a particular
        // window. Without a live producer action or revalidated provenance,
        // leaving the notification in history is safer than guessing.
        return false
    }

    function invokeAction(entry, index: int): void {
        const actions = visibleActions(entry)
        const action = actions.length > index ? actions[index] : null
        if (action)
            action.invoke()
    }

    function remove(entry): void {
        if (!entry)
            return
        if (entry.active && entry.source)
            entry.source.dismiss()
        history = history.filter(existing => existing.id !== entry.id
            || existing.timestamp !== entry.timestamp)
        if (current?.id === entry.id && current?.timestamp === entry.timestamp) {
            current = null
            presentationDismissRequested()
        }
    }

    function dismissTransient(): void {
        requestTransientDismiss(current)
    }

    function requestTransientDismiss(entry): void {
        if (!entry)
            return
        if (current?.id !== entry.id || current?.timestamp !== entry.timestamp) {
            remove(entry)
            return
        }
        if (pendingTransientDismiss)
            return
        pendingTransientDismiss = entry
        transientDismissRequested()
    }

    function completeTransientDismiss(): void {
        const entry = pendingTransientDismiss
        pendingTransientDismiss = null
        if (entry)
            remove(entry)
    }

    function clearHistory(): void {
        for (const entry of history) {
            if (entry.active && entry.source)
                entry.source.dismiss()
        }
        if (current)
            presentationDismissRequested()
        current = null
        history = []
    }

    function toggleDoNotDisturb(): void {
        setDoNotDisturb(!doNotDisturb)
    }

    function setDoNotDisturb(enabled: bool): void {
        SettingsStore.setNotificationToggle("doNotDisturb", enabled)
        if (enabled && current) {
            current = null
            presentationDismissRequested()
        }
    }

    function setShowPopups(enabled: bool): void {
        SettingsStore.setNotificationToggle("showPopups", enabled)
        if (!enabled && current && !currentCritical) {
            current = null
            presentationDismissRequested()
        }
    }

    function setAllowCriticalAlerts(enabled: bool): void {
        SettingsStore.setNotificationToggle("allowCriticalAlerts", enabled)
        if (!enabled && currentCritical) {
            current = null
            presentationDismissRequested()
        }
    }

    function setDuration(key: string, milliseconds: real): void {
        SettingsStore.setNotificationDuration(key, milliseconds)
    }

    function setHistoryLimit(limit: real): void {
        if (SettingsStore.setNotificationHistoryLimit(limit))
            history = history.slice(0, Math.round(Math.max(20,
                Math.min(100, limit))))
    }

    function resetPreferences(): void {
        SettingsStore.resetNotifications()
        history = history.slice(0, 50)
    }

    function bindProvenance(notificationId, pid, availableToplevels): void {
        const id = Number(notificationId)
        const senderPid = Number(pid)
        if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(senderPid)
                || senderPid <= 0)
            return
        const provenance = HyprlandService.snapshotToplevelForPid(senderPid,
            availableToplevels)
        if (!provenance)
            return
        const index = history.findIndex(entry => entry.id === id
            && entry.provenance === null)
        if (index < 0) {
            cachePendingProvenance(id, provenance)
            return
        }
        const updated = history.slice()
        updated[index] = Object.assign({}, updated[index], { provenance: provenance })
        history = updated
        if (current?.id === id && current?.timestamp === updated[index].timestamp)
            current = updated[index]
    }

    function startProvenanceObserver(): void {
        if (!serverEnabled || provenanceProcess.running)
            return
        provenanceRestartPending = false
        provenanceProcess.command = ["python3", provenanceHelperPath]
        provenanceProcess.running = true
    }

    onServerEnabledChanged: {
        if (serverEnabled)
            startProvenanceObserver()
        else if (provenanceProcess.running)
            provenanceProcess.signal(15)
    }

    Component.onCompleted: startProvenanceObserver()

    property Timer provenanceRestartTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: root.startProvenanceObserver()
    }

    property Timer exactFocusTimer: Timer {
        // IslandController releases HyprlandFocusGrab after Animations.fast.
        interval: Animations.fast + 40
        repeat: false
        onTriggered: {
            const provenance = root.pendingExactFocus
            root.pendingExactFocus = null
            if (provenance)
                HyprlandService.focusExactProvenance(provenance)
        }
    }

    property Process provenanceProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    if (event?.version === 1 && event?.event === "provenance"
                            && Object.keys(event).length === 4)
                        root.bindProvenance(event.notificationId, event.pid)
                } catch (error) {
                    console.warn("Odyssey notification provenance parse failed")
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.serverEnabled && !root.provenanceRestartPending) {
                root.provenanceRestartPending = true
                root.provenanceRestartTimer.restart()
            }
        }
    }

    Instantiator {
        model: root.serverEnabled ? 1 : 0

        delegate: NotificationServer {
            keepOnReload: false
            persistenceSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: false
            bodyImagesSupported: true
            actionsSupported: true
            actionIconsSupported: true
            imageSupported: true
            inlineReplySupported: false

            onNotification: notification => root.receive(notification)
        }
    }
}
