pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool exporting: false
    property bool available: false
    property bool refreshPending: false
    property string lastMode: ""
    property string lastOutput: ""
    property string errorMessage: ""

    readonly property string stateRoot: {
        const configured = Quickshell.env("XDG_STATE_HOME") || ""
        return configured.length > 0 ? configured
            : Quickshell.env("HOME") + "/.local/state"
    }
    readonly property string exportDirectory:
        stateRoot + "/odyssey/theme-exports"
    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/export-theme.sh"
    readonly property string palettePath:
        Config.appearance.activePalettePath
    readonly property string activeMode: Theme.dark ? "dark" : "light"
    readonly property string statusLabel: exporting ? "Exporting theme…"
        : errorMessage.length > 0 ? errorMessage
        : available ? "Theme exports ready" : "Theme exports unavailable"

    signal exported(string directory, string mode)

    function refresh(): void {
        if (!Config.externalThemes.exportEnabled)
            return
        if (exportProcess.running) {
            refreshPending = true
            return
        }
        exporting = true
        errorMessage = ""
        lastOutput = ""
        exportProcess.command = [helperPath, palettePath, activeMode,
            exportDirectory, Config.externalThemes.hyprlockEnabled
                ? "true" : "false"]
        exportProcess.running = true
    }

    property Timer refreshTimer: Timer {
        interval: Animations.fast
        onTriggered: root.refresh()
    }

    property Connections themeConnections: Connections {
        target: Theme
        function onColorsChanged(): void { root.refreshTimer.restart() }
    }

    property Connections settingsConnections: Connections {
        target: SettingsStore
        function onValuesChanged(): void { root.refreshTimer.restart() }
    }

    property Process exportProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.lastOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.errorMessage = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            root.exporting = false
            root.available = exitCode === 0
            if (exitCode === 0) {
                root.lastMode = root.activeMode
                root.errorMessage = ""
                root.exported(root.exportDirectory, root.lastMode)
            } else {
                root.errorMessage = root.errorMessage
                    || "Theme export failed"
                console.warn("Odyssey ThemeExportService:", root.errorMessage)
            }
            if (root.refreshPending) {
                root.refreshPending = false
                Qt.callLater(() => root.refresh())
            }
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "theme-export"

        function refresh(): string {
            root.refresh()
            return "THEME_EXPORT_REFRESH_REQUESTED"
        }

        function status(): string {
            return root.statusLabel
        }

        function path(): string {
            return root.exportDirectory
        }
    }
}
