pragma Singleton
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../core"

QtObject {
    id: root

    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedToplevel: Hyprland.activeToplevel
    readonly property var monitors: Hyprland.monitors?.values || []
    readonly property var connectedMonitors: monitors.slice().sort((left, right) =>
        left.id - right.id)
    readonly property var workspaces: Hyprland.workspaces?.values || []
    readonly property var toplevels: Hyprland.toplevels?.values || []

    readonly property int activeWorkspaceId: focusedWorkspace?.id ?? 0
    readonly property bool fullscreen: focusedWorkspace?.hasFullscreen ?? false
    // Hyprland's client JSON encodes true fullscreen as 1 and workspace-fill
    // (the `fullscreen, 1` dispatcher mode) as 2. Keep this distinction at
    // the service boundary so UI surfaces do not need to inspect IPC maps.
    readonly property int focusedFullscreenMode: Number(
        focusedToplevel?.lastIpcObject?.fullscreen ?? 0)
    readonly property string focusedWindow: focusedToplevel?.title || ""
    readonly property string focusedApplication: applicationName(focusedToplevel)
    readonly property var occupiedWorkspaces: workspaces.filter(workspace =>
        (workspace?.toplevels?.values?.length || 0) > 0)
    readonly property var urgentWorkspaces: workspaces.filter(workspace => workspace?.urgent ?? false)
    readonly property var primaryMonitor: resolvePrimaryMonitor()
    readonly property string primaryMonitorName: primaryMonitor?.name || ""
    readonly property bool primaryPreferenceAvailable:
        Config.displays.primaryMonitor === "auto"
            || connectedMonitors.some(monitor =>
                monitor?.name === Config.displays.primaryMonitor)

    signal contextChanged()
    signal topologyChanged()

    function applicationName(toplevel): string {
        if (!toplevel)
            return "Desktop"

        const ipc = toplevel.lastIpcObject || {}
        return ipc.class || ipc.initialClass || toplevel.wayland?.appId || "Application"
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen)
    }

    function validAddress(value): bool {
        return /^0x[0-9a-f]+$/i.test(String(value || ""))
    }

    function stableClientId(toplevel): string {
        // Current Hyprland client maps do not guarantee a stable client ID.
        // Preserve one only if a future backend explicitly supplies it.
        const value = toplevel?.lastIpcObject?.stableId
        return value === undefined || value === null || String(value).length === 0
            ? "" : String(value)
    }

    function snapshotToplevelForPid(pid: int, availableToplevels): var {
        const requestedPid = Number(pid)
        if (!Number.isInteger(requestedPid) || requestedPid <= 0)
            return null
        const candidates = (availableToplevels || toplevels).filter(toplevel =>
            Number(toplevel?.lastIpcObject?.pid) === requestedPid
                && validAddress(toplevel?.lastIpcObject?.address || toplevel?.address))
        if (candidates.length !== 1)
            return null
        const candidate = candidates[0]
        return { address: String(candidate.lastIpcObject?.address || candidate.address),
            pid: requestedPid, stableId: stableClientId(candidate) }
    }

    function exactProvenanceTarget(provenance, availableToplevels): var {
        if (!provenance || !validAddress(provenance.address))
            return null
        const pid = Number(provenance.pid)
        if (!Number.isInteger(pid) || pid <= 0)
            return null
        const stableId = String(provenance.stableId || "")
        const candidates = (availableToplevels || toplevels).filter(toplevel => {
            const ipc = toplevel?.lastIpcObject || {}
            const address = String(ipc.address || toplevel?.address || "")
            return address === provenance.address && Number(ipc.pid) === pid
                && (stableId.length === 0 || stableClientId(toplevel) === stableId)
        })
        if (candidates.length !== 1)
            return null
        return candidates[0]
    }

    function hasValidExactProvenance(provenance, availableToplevels): bool {
        return exactProvenanceTarget(provenance, availableToplevels) !== null
    }

    function exactProvenanceFocusCommand(provenance, availableToplevels): string {
        const target = exactProvenanceTarget(provenance, availableToplevels)
        const address = String(target?.lastIpcObject?.address || target?.address || "")
        if (!validAddress(address))
            return ""
        return "hl.dsp.focus({ window = "
            + JSON.stringify("address:" + address) + " })"
    }

    function focusExactProvenance(provenance): bool {
        const command = exactProvenanceFocusCommand(provenance)
        if (!command)
            return false
        // The command is built only after the live toplevel still matches the
        // captured address, PID, and stable client identity.
        Hyprland.dispatch(command)
        return true
    }

    function fullscreenModeOn(workspace): int {
        const toplevels = workspace?.toplevels?.values || []
        for (const toplevel of toplevels) {
            const mode = Number(toplevel?.lastIpcObject?.fullscreen ?? 0)
            if (mode > 0)
                return mode
        }
        return 0
    }

    function trueFullscreenOn(workspace): bool {
        return fullscreenModeOn(workspace) === 1
    }

    function workspaceFillOn(workspace): bool {
        return fullscreenModeOn(workspace) === 2
    }

    function monitorIsFocused(monitor): bool {
        return monitor !== null && monitor !== undefined
            && focusedMonitor !== null && focusedMonitor !== undefined
            && monitor.id === focusedMonitor.id
    }

    function resolvePrimaryMonitor(): var {
        if (connectedMonitors.length === 0)
            return null
        if (Config.displays.primaryMonitor !== "auto") {
            const preferred = connectedMonitors.find(monitor =>
                monitor?.name === Config.displays.primaryMonitor)
            if (preferred)
                return preferred
        }
        const internal = connectedMonitors.find(monitor =>
            /^(eDP|LVDS|DSI)-/i.test(monitor?.name || ""))
        return internal || connectedMonitors[0]
    }

    function monitorIsPrimary(monitor): bool {
        return monitor !== null && monitor !== undefined
            && primaryMonitor !== null && primaryMonitor !== undefined
            && monitor.id === primaryMonitor.id
    }

    function islandEnabledFor(monitor): bool {
        return Config.displays.islandPolicy === "all" || monitorIsPrimary(monitor)
    }

    function shouldPresentOn(monitor): bool {
        return Config.displays.islandPolicy === "primary"
            ? monitorIsPrimary(monitor) : monitorIsFocused(monitor)
    }

    function monitorLabel(monitor): string {
        if (!monitor)
            return "Display"
        const name = monitor.name || "Display"
        return /^(eDP|LVDS|DSI)-/i.test(name) ? name + " · Built-in" : name
    }

    function setIslandPolicy(policy: string): bool {
        return SettingsStore.setIslandMonitorPolicy(policy)
    }

    function setPrimaryMonitor(monitorName: string): bool {
        return SettingsStore.setPrimaryMonitor(monitorName)
    }

    function resetDisplayPreferences(): void {
        SettingsStore.resetDisplays()
    }

    function workspacesFor(monitor): var {
        if (!monitor)
            return []
        return workspaces.filter(workspace => workspace?.monitor?.id === monitor.id)
            .sort((left, right) => left.id - right.id)
    }

    function workspaceById(workspaceId: int): var {
        for (const workspace of workspaces) {
            if (workspace?.id === workspaceId)
                return workspace
        }
        return null
    }

    function workspaceWindowCount(workspace: var): int {
        return workspace?.toplevels?.values?.length || 0
    }

    function activateWorkspace(workspaceId: int): bool {
        const id = Number(workspaceId)
        if (!Number.isInteger(id) || id < 1
                || id > Config.hyprland.workspaceCount) {
            console.warn("Odyssey refused invalid workspace id:", workspaceId)
            return false
        }

        const existing = workspaceById(id)
        if (existing) {
            existing.activate()
            return true
        }

        // Hyprland creates an empty numeric workspace on demand. The id is
        // validated above before it becomes part of the native IPC request.
        Hyprland.dispatch(`workspace ${id}`)
        return true
    }

    property Connections hyprlandEvents: Connections {
        target: Hyprland
        function onFocusedMonitorChanged(): void { root.contextChanged() }
        function onFocusedWorkspaceChanged(): void { root.contextChanged() }
        function onActiveToplevelChanged(): void { root.contextChanged() }
        function onRawEvent(event): void {
            const meaningfulEvents = [
                "activewindow", "activewindowv2", "closewindow", "focusedmon",
                "focusedmonv2", "fullscreen", "openwindow", "urgent", "workspace",
                "workspacev2"
            ]
            if (meaningfulEvents.indexOf(event.name) !== -1) {
                Hyprland.refreshToplevels()
                root.contextChanged()
            }
            const topologyEvents = [
                "monitoradded", "monitoraddedv2", "monitorremoved",
                "monitorremovedv2"
            ]
            if (topologyEvents.indexOf(event.name) !== -1) {
                root.topologyChanged()
                root.contextChanged()
            }
        }
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    property IpcHandler displayIpc: IpcHandler {
        target: "displays"

        function status(): string {
            return "POLICY=" + Config.displays.islandPolicy
                + " PRIMARY=" + root.primaryMonitorName
                + " CONNECTED=" + root.connectedMonitors.length
        }

        function policy(policy: string): string {
            return root.setIslandPolicy(policy)
                ? "DISPLAY_POLICY_UPDATED" : "DISPLAY_POLICY_REJECTED"
        }

        function primary(monitorName: string): string {
            return root.setPrimaryMonitor(monitorName)
                ? "PRIMARY_MONITOR_UPDATED" : "PRIMARY_MONITOR_REJECTED"
        }

        function reset(): string {
            root.resetDisplayPreferences()
            return "DISPLAY_PREFERENCES_RESET"
        }
    }
}
