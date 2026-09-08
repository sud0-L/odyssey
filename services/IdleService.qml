pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool inhibited: false
    property bool busy: false
    property bool installed: false
    property string errorMessage: ""
    property string lastOutput: ""
    property string pendingAction: ""
    property bool applyQueued: false

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/idlectl.sh"
    readonly property string statusLabel: inhibited ? "Keep awake is active"
        : busy ? "Updating idle policy…"
        : errorMessage.length > 0 ? errorMessage
        : installed ? "Odyssey manages idle timing"
        : "Hypridle is under manual control"

    signal inhibitionChanged(bool inhibited)

    property IpcHandler idleIpc: IpcHandler {
        target: "idle"

        function toggle(): string {
            root.toggleInhibition()
            return root.inhibited ? "IDLE_INHIBITED" : "IDLE_NORMAL"
        }

        function status(): string {
            return root.inhibited ? "INHIBITED" : "NORMAL"
        }

        function reset(): string {
            root.resetPolicy()
            return "IDLE_DEFAULTS_RESTORED"
        }
    }

    function toggleInhibition(): void {
        inhibited = !inhibited
        inhibitionChanged(inhibited)
    }

    function policyArguments(command: string): var {
        return [helperPath, command,
            Math.round(Config.idle.dimMinutes * 60).toString(),
            Math.round(Config.idle.lockMinutes * 60).toString(),
            Math.round(Config.idle.displayOffMinutes * 60).toString(),
            Math.round(Config.idle.suspendMinutes * 60).toString(),
            Math.round(Config.idle.hibernateMinutes * 60).toString(),
            Config.idle.dimPercent.toString()]
    }

    function probe(): void {
        if (busy)
            return
        pendingAction = "probe"
        process.command = [helperPath, "status"]
        process.running = true
    }

    function applyPolicy(): void {
        if (busy) {
            applyQueued = true
            return
        }
        applyQueued = false
        busy = true
        errorMessage = ""
        pendingAction = "apply"
        process.command = policyArguments("apply")
        process.running = true
    }

    function setManaged(enabled: bool): void {
        if (busy)
            return
        SettingsStore.setIdleManaged(enabled)
        busy = true
        errorMessage = ""
        pendingAction = enabled ? "apply" : "remove"
        process.command = enabled ? policyArguments("apply")
            : [helperPath, "remove"]
        process.running = true
    }

    function setMetric(metric: string, value: real): void {
        if (SettingsStore.setIdleMetric(metric, value))
            applyDelay.restart()
    }

    function resetPolicy(): void {
        SettingsStore.resetIdlePolicy()
        Qt.callLater(() => applyPolicy())
    }

    property Timer applyDelay: Timer {
        interval: 420
        onTriggered: {
            if (Config.idle.managed)
                root.applyPolicy()
        }
    }

    property Process process: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.lastOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.errorMessage = text.trim()
        }
        onExited: exitCode => {
            const action = root.pendingAction
            root.busy = false
            root.pendingAction = ""
            if (exitCode !== 0) {
                root.errorMessage = root.errorMessage
                    || "Idle policy update failed"
                console.warn("Odyssey IdleService:", root.errorMessage)
                return
            }
            root.errorMessage = ""
            root.installed = root.lastOutput.includes("MANAGED=true")
            if (action === "probe" && Config.idle.managed && !root.installed)
                Qt.callLater(() => root.applyPolicy())
            else if (root.applyQueued && Config.idle.managed)
                Qt.callLater(() => root.applyPolicy())
        }
    }

    Component.onCompleted: probe()
}
