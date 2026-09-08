pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool screenshotAvailable: false
    property bool clipboardAvailable: false
    property bool recordingAvailable: false
    property bool regionAvailable: false
    property bool screenshotBusy: false
    property bool preparingRecording: false
    property bool recording: false
    property bool stopping: false
    property bool systemAudio: true
    property int elapsedSeconds: 0
    property double recordingStartedAt: 0
    property string lastOutputPath: ""
    property string statusMessage: "Checking capture tools…"
    property string errorMessage: ""
    property string screenshotOutput: ""
    property string screenshotError: ""
    property string prepareOutput: ""
    property string prepareError: ""
    property string recorderError: ""
    property string pendingScreenshotMode: ""
    property string pendingScreenshotMonitor: ""
    property string pendingScreenshotOutput: "both"
    property string pendingRecordingMode: ""
    property string pendingRecordingMonitor: ""
    property bool pendingRecordingAudio: true

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/capturectl.sh"
    readonly property string elapsedLabel: {
        const minutes = Math.floor(elapsedSeconds / 60)
        const seconds = elapsedSeconds % 60
        return String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0")
    }
    readonly property string recordingFileName: fileName(lastOutputPath)
    readonly property bool busy: screenshotBusy || preparingRecording || stopping
        || screenshotDelay.running || recordingDelay.running

    signal screenshotFinished(bool success, string path, bool copied)
    signal recordingStarted(string path)
    signal recordingFinished(bool success, string path)

    function fileName(path: string): string {
        return path ? path.substring(path.lastIndexOf("/") + 1) : ""
    }

    function field(output: string, name: string): string {
        const prefix = name + "="
        for (const line of output.split("\n")) {
            if (line.startsWith(prefix))
                return line.substring(prefix.length)
        }
        return ""
    }

    function validScreenshotMode(mode: string): bool {
        return ["full", "monitor", "region", "active"].includes(mode)
    }

    function validOutputMode(mode: string): bool {
        return ["save", "copy", "both"].includes(mode)
    }

    function scheduleScreenshot(mode: string, monitorName: string,
            outputMode: string): bool {
        if (!screenshotAvailable || screenshotBusy || screenshotDelay.running
                || recording
                || !validScreenshotMode(mode) || !validOutputMode(outputMode))
            return false
        if (mode === "region" && !regionAvailable)
            return false
        if (mode === "monitor" && !monitorName)
            return false
        pendingScreenshotMode = mode
        pendingScreenshotMonitor = monitorName || ""
        pendingScreenshotOutput = outputMode
        statusMessage = mode === "region" ? "Select a region"
            : "Preparing screenshot…"
        errorMessage = ""
        screenshotDelay.restart()
        return true
    }

    function takePendingScreenshot(): void {
        screenshotOutput = ""
        screenshotError = ""
        screenshotBusy = true
        screenshotProcess.command = [helperPath, "screenshot",
            pendingScreenshotMode, pendingScreenshotMonitor,
            pendingScreenshotOutput]
        screenshotProcess.running = true
    }

    function scheduleRecording(mode: string, monitorName: string,
            includeSystemAudio: bool): bool {
        if (!recordingAvailable || recording || preparingRecording
                || recordingDelay.running
                || screenshotBusy || (mode !== "monitor" && mode !== "region"))
            return false
        if (mode === "region" && !regionAvailable)
            return false
        if (mode === "monitor" && !monitorName)
            return false
        pendingRecordingMode = mode
        pendingRecordingMonitor = monitorName || ""
        pendingRecordingAudio = includeSystemAudio
        statusMessage = mode === "region" ? "Select a recording region"
            : "Preparing recording…"
        errorMessage = ""
        recordingDelay.restart()
        return true
    }

    function preparePendingRecording(): void {
        prepareOutput = ""
        prepareError = ""
        preparingRecording = true
        prepareProcess.command = [helperPath, "prepare-recording",
            pendingRecordingMode, pendingRecordingMonitor]
        prepareProcess.running = true
    }

    function launchRecording(): bool {
        const outputPath = field(prepareOutput, "PATH")
        const target = field(prepareOutput, "TARGET")
        const region = field(prepareOutput, "REGION")
        if (!outputPath || !target)
            return false

        const command = ["gpu-screen-recorder", "-w", target,
            "-f", Config.capture.frameRate.toString(), "-k", "h264",
            "-c", "mp4", "-fm", "vfr", "-cursor", "yes"]
        if (region)
            command.push("-region", region)
        if (pendingRecordingAudio)
            command.push("-a", "default_output")
        command.push("-o", outputPath)

        lastOutputPath = outputPath
        recorderError = ""
        recordProcess.command = command
        recordProcess.running = true
        return true
    }

    function stopRecording(): bool {
        if (!recording || stopping || !recordProcess.running)
            return false
        stopping = true
        statusMessage = "Saving recording…"
        recordProcess.signal(2)
        return true
    }

    function refreshAvailability(): void {
        if (!probeProcess.running)
            probeProcess.running = true
    }

    property Timer screenshotDelay: Timer {
        interval: Config.capture.shellClearDelay
        onTriggered: root.takePendingScreenshot()
    }

    property Timer recordingDelay: Timer {
        interval: Config.capture.shellClearDelay
        onTriggered: root.preparePendingRecording()
    }

    property Timer elapsedTimer: Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds = Math.max(0,
            Math.floor((Date.now() - root.recordingStartedAt) / 1000))
    }

    property Process probeProcess: Process {
        command: [root.helperPath, "probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.screenshotAvailable = root.field(text, "SCREENSHOT") === "ready"
                root.clipboardAvailable = root.field(text, "CLIPBOARD") === "ready"
                root.recordingAvailable = root.field(text, "RECORDING") === "ready"
                root.regionAvailable = root.field(text, "REGION") === "ready"
            }
        }
        onExited: exitCode => {
            root.statusMessage = exitCode === 0
                ? "Capture tools ready" : "Capture tools unavailable"
        }
    }

    property Process screenshotProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.screenshotOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.screenshotError = text.trim()
        }
        onExited: exitCode => {
            root.screenshotBusy = false
            if (exitCode === 0) {
                const saved = root.field(root.screenshotOutput, "SAVED") === "true"
                const copied = root.field(root.screenshotOutput, "COPIED") === "true"
                const path = root.field(root.screenshotOutput, "PATH")
                root.lastOutputPath = path
                root.statusMessage = saved && copied ? "Screenshot saved and copied"
                    : saved ? "Screenshot saved" : "Screenshot copied"
                root.errorMessage = ""
                root.screenshotFinished(true, path, copied)
            } else if (exitCode === 2) {
                root.statusMessage = "Screenshot cancelled"
                root.errorMessage = ""
                root.screenshotFinished(false, "", false)
            } else {
                root.errorMessage = root.screenshotError || "Screenshot failed"
                root.statusMessage = root.errorMessage
                root.screenshotFinished(false, "", false)
                console.warn("Odyssey CaptureService screenshot:", root.errorMessage)
            }
        }
    }

    property Process prepareProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.prepareOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.prepareError = text.trim()
        }
        onExited: exitCode => {
            root.preparingRecording = false
            if (exitCode === 0 && root.launchRecording())
                return
            if (exitCode === 2) {
                root.statusMessage = "Recording cancelled"
                root.errorMessage = ""
            } else {
                root.errorMessage = root.prepareError || "Could not start recording"
                root.statusMessage = root.errorMessage
                console.warn("Odyssey CaptureService preparation:", root.errorMessage)
            }
        }
    }

    property Process recordProcess: Process {
        running: false
        stdout: SplitParser { onRead: line => {} }
        stderr: SplitParser {
            onRead: line => {
                if (/\b(error|failed|fatal)\b/i.test(line))
                    root.recorderError = line.trim()
            }
        }
        onStarted: {
            root.recording = true
            root.stopping = false
            root.elapsedSeconds = 0
            root.recordingStartedAt = Date.now()
            root.statusMessage = "Recording " + root.recordingFileName
            root.errorMessage = ""
            root.recordingStarted(root.lastOutputPath)
        }
        onExited: exitCode => {
            const wasRecording = root.recording
            root.recording = false
            root.stopping = false
            root.elapsedSeconds = 0
            if (!wasRecording)
                return
            const success = exitCode === 0
            root.statusMessage = success ? "Recording saved" : "Recording stopped unexpectedly"
            root.errorMessage = success ? ""
                : (root.recorderError || "Recording backend exited unexpectedly")
            root.recordingFinished(success, root.lastOutputPath)
            if (!success)
                console.warn("Odyssey CaptureService recording:", root.errorMessage)
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "capture"

        function screenshot(mode: string, outputMode: string): string {
            const monitorName = HyprlandService.focusedMonitor?.name || ""
            return root.scheduleScreenshot(mode, monitorName, outputMode)
                ? "SCREENSHOT_REQUESTED" : "SCREENSHOT_UNAVAILABLE"
        }

        function record(mode: string): string {
            const monitorName = HyprlandService.focusedMonitor?.name || ""
            return root.scheduleRecording(mode, monitorName, true)
                ? "RECORDING_REQUESTED" : "RECORDING_UNAVAILABLE"
        }

        function stop(): string {
            return root.stopRecording() ? "RECORDING_STOP_REQUESTED"
                : "RECORDING_NOT_ACTIVE"
        }

        function status(): string {
            return root.recording ? "recording " + root.elapsedLabel
                : root.statusMessage
        }
        function output(): string {
            return root.lastOutputPath
        }
    }

    Component.onCompleted: refreshAvailability()
}
