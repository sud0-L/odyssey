pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool available: false
    property bool monitorAvailable: false
    property bool initialized: false
    property bool eventsEnabled: false
    property int percentage: 0
    property string deviceName: "Display"
    property string deviceId: ""
    property int rawValue: 0
    property int maximumRawValue: 0
    property string managedOperation: ""
    property double managedOperationAt: 0

    readonly property real level: percentage / 100

    signal brightnessChanged(real level, string deviceName)

    function managedOperationIsCurrent(): bool {
        return managedOperation.length > 0
            && Date.now() - managedOperationAt < 5000
    }

    function loadManagedOperation(raw: string): void {
        const parts = raw.trim().split(/\s+/)
        const timestamp = Number(parts[1])
        managedOperation = (parts[0] === "dim" || parts[0] === "restore")
            && Number.isFinite(timestamp) ? parts[0] : ""
        managedOperationAt = Number.isFinite(timestamp) ? timestamp * 1000 : 0
    }

    function parseInfo(text): void {
        const line = text.trim().split("\n")[0]
        const fields = line.split(",")
        if (fields.length < 5)
            return

        const parsedRaw = Number(fields[2])
        const parsedPercentage = Number(fields[3].replace("%", ""))
        const parsedMaximum = Number(fields[4])
        if (!Number.isFinite(parsedRaw) || !Number.isFinite(parsedPercentage)
                || !Number.isFinite(parsedMaximum) || parsedMaximum <= 0)
            return

        const oldPercentage = percentage
        deviceId = fields[0]
        deviceName = fields[0] || "Display"
        rawValue = parsedRaw
        maximumRawValue = parsedMaximum
        percentage = Math.max(0, Math.min(100, Math.round(parsedPercentage)))
        available = true

        // The idle helper marks only its own dim/restore writes, leaving manual
        // and hardware-key brightness changes visible through the island OSD.
        if (initialized && eventsEnabled && oldPercentage !== percentage
                && !managedOperationIsCurrent())
            brightnessChanged(level, deviceName)
        initialized = true
    }

    function requestRefresh(): void {
        refreshDebounce.restart()
    }

    function refresh(): void {
        if (!infoQuery.running)
            infoQuery.running = true
    }

    function setBrightness(percent): void {
        if (!available || setQuery.running)
            return
        const clamped = Math.max(1, Math.min(100, Math.round(percent)))
        setQuery.command = ["brightnessctl", "--device", deviceId, "set", clamped + "%"]
        setQuery.running = true
    }

    property Timer refreshDebounce: Timer {
        interval: 60
        onTriggered: root.refresh()
    }

    property Timer startupGuard: Timer {
        interval: 900
        running: true
        onTriggered: root.eventsEnabled = true
    }

    property FileView managedOperationFile: FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
            + "/odyssey/idle-brightness"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadManagedOperation(text())
        onFileChanged: reload()
        onLoadFailed: {
            root.managedOperation = ""
            root.managedOperationAt = 0
        }
    }

    property Process infoQuery: Process {
        command: ["brightnessctl", "--machine-readable", "info"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseInfo(text)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.available = false
        }
    }

    property Process eventMonitor: Process {
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                if (line.includes(" change "))
                    root.requestRefresh()
            }
        }

        onStarted: root.monitorAvailable = true
        onExited: (exitCode, exitStatus) => root.monitorAvailable = false
    }

    property Process setQuery: Process {
        running: false
        onExited: (exitCode, exitStatus) => root.requestRefresh()
    }

    Component.onCompleted: refresh()
}
