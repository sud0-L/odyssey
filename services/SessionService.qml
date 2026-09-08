pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool lockAvailable: false
    property bool logoutAvailable: false
    property bool suspendAvailable: false
    property bool hibernateAvailable: false
    property bool rebootAvailable: false
    property bool shutdownAvailable: false
    property bool probing: false
    property bool executing: false
    property string pendingAction: ""
    property string activeAction: ""
    property string probeOutput: ""
    property string actionError: ""
    property string statusMessage: "Checking session capabilities…"

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/sessionctl.sh"

    signal actionStarted(string action)
    signal actionFailed(string action, string message)

    property IpcHandler sessionIpc: IpcHandler {
        target: "session"

        function lock(): string {
            return root.schedule("lock")
                ? "LOCK_SCHEDULED" : "LOCK_UNAVAILABLE"
        }
    }

    function field(output: string, name: string): string {
        const prefix = name + "="
        for (const line of output.split("\n")) {
            if (line.startsWith(prefix))
                return line.substring(prefix.length)
        }
        return ""
    }

    function isKnownAction(action: string): bool {
        return ["lock", "suspend", "hibernate", "logout", "reboot",
            "shutdown"].includes(action)
    }

    function isAvailable(action: string): bool {
        if (action === "lock") return lockAvailable
        if (action === "suspend") return suspendAvailable
        if (action === "hibernate") return hibernateAvailable
        if (action === "logout") return logoutAvailable
        if (action === "reboot") return rebootAvailable
        if (action === "shutdown") return shutdownAvailable
        return false
    }

    function schedule(action: string): bool {
        if (!isKnownAction(action) || !isAvailable(action) || executing
                || actionDelay.running)
            return false
        pendingAction = action
        actionError = ""
        statusMessage = "Preparing " + action + "…"
        actionDelay.restart()
        return true
    }

    function executePending(): void {
        if (!isKnownAction(pendingAction) || !isAvailable(pendingAction)) {
            pendingAction = ""
            statusMessage = "Session action unavailable"
            return
        }
        activeAction = pendingAction
        pendingAction = ""
        executing = true
        actionError = ""
        actionProcess.command = [helperPath, activeAction]
        actionProcess.running = true
    }

    function refresh(): void {
        if (probeProcess.running)
            return
        probing = true
        probeOutput = ""
        probeProcess.running = true
    }

    property Timer actionDelay: Timer {
        interval: Config.session.shellClearDelay
        onTriggered: root.executePending()
    }

    property Process probeProcess: Process {
        running: false
        command: [root.helperPath, "probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.probeOutput = text
                root.lockAvailable = root.field(text, "LOCK") === "ready"
                root.logoutAvailable = root.field(text, "LOGOUT") === "ready"
                root.suspendAvailable = root.field(text, "SUSPEND") === "ready"
                root.hibernateAvailable = root.field(text, "HIBERNATE") === "ready"
                root.rebootAvailable = root.field(text, "REBOOT") === "ready"
                root.shutdownAvailable = root.field(text, "SHUTDOWN") === "ready"
            }
        }
        onExited: exitCode => {
            root.probing = false
            root.statusMessage = exitCode === 0
                ? "Session controls ready" : "Session controls unavailable"
        }
    }

    property Process actionProcess: Process {
        running: false
        stderr: StdioCollector {
            onStreamFinished: root.actionError = text.trim()
        }
        onStarted: {
            root.statusMessage = "Running " + root.activeAction + "…"
            root.actionStarted(root.activeAction)
        }
        onExited: exitCode => {
            const completedAction = root.activeAction
            root.executing = false
            root.activeAction = ""
            if (exitCode !== 0) {
                root.actionError = root.actionError
                    || "The session action could not be completed"
                root.statusMessage = root.actionError
                root.actionFailed(completedAction, root.actionError)
                console.warn("Odyssey SessionService:", completedAction,
                    root.actionError)
            } else {
                root.statusMessage = "Session controls ready"
            }
        }
    }

    Component.onCompleted: refresh()
}
