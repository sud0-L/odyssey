pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool busy: false
    property bool installed: false
    property string errorMessage: ""
    property string lastOutput: ""
    property string pendingAction: ""
    property bool pendingValue: false

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/shortcutctl.sh"
    // The helper reads the exact supported main-config path from the active
    // startup receipt, avoiding format guesses in the running shell.
    readonly property string configPath: ""
    readonly property string statusLabel: busy ? "Updating Hyprland…"
        : errorMessage.length > 0 ? errorMessage
        : installed ? "Odyssey manages these shell shortcuts"
        : "Hyprland retains manual control"
    readonly property var entries: [
        { id: "launcher", label: "Application launcher", keys: "Super + A" },
        { id: "commandLauncher", label: "Command launcher", keys: "Super + Ctrl + A" },
        { id: "clipboard", label: "Clipboard history", keys: "Super + V" },
        { id: "settings", label: "Odyssey settings", keys: "Super + ," },
        { id: "notifications", label: "Notifications", keys: "Super + N" },
        { id: "wallpaper", label: "Wallpaper library", keys: "Super + Y" },
        { id: "controlCenter", label: "Control Center", keys: "Super + Space" },
        { id: "lock", label: "Lock session", keys: "Super + Alt + L" },
        { id: "regionScreenshot", label: "Select-area screenshot",
            keys: "Super + Shift + S" },
        { id: "regionRecording", label: "Select-area recording",
            keys: "Super + Shift + R" }
    ]

    function enabled(action: string): bool {
        return Boolean(Config.shortcuts[action])
    }

    function commandArguments(command: string, overrideAction: string,
            overrideValue: bool): var {
        const values = []
        for (const entry of entries) {
            const value = entry.id === overrideAction
                ? overrideValue : enabled(entry.id)
            values.push(value ? "true" : "false")
        }
        return [helperPath, command, configPath].concat(values)
    }

    function probe(): void {
        if (busy)
            return
        process.command = [helperPath, "status", configPath]
        process.running = true
    }

    function setManaged(enabled: bool): void {
        if (busy || enabled === installed)
            return
        busy = true
        errorMessage = ""
        pendingAction = "managed"
        pendingValue = enabled
        process.command = root.commandArguments(enabled ? "apply" : "remove",
            "", false)
        process.running = true
    }

    function setEnabled(action: string, enabled: bool): void {
        if (busy || !entries.some(entry => entry.id === action))
            return
        if (!installed) {
            SettingsStore.setShortcutEnabled(action, enabled)
            return
        }
        busy = true
        errorMessage = ""
        pendingAction = action
        pendingValue = enabled
        process.command = root.commandArguments("apply", action, enabled)
        process.running = true
    }

    function resetPreferences(): void {
        if (busy)
            return
        if (!installed) {
            SettingsStore.resetShortcuts()
            return
        }
        busy = true
        errorMessage = ""
        pendingAction = "reset"
        pendingValue = true
        process.command = [helperPath, "apply", configPath,
            "true", "true", "true", "true", "true", "true", "true", "true",
            "true", "true"]
        process.running = true
    }

    property Process process: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.lastOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.errorMessage = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            const action = root.pendingAction
            root.busy = false
            if (exitCode !== 0) {
                root.errorMessage = root.errorMessage
                    || "Shortcut update failed"
                root.pendingAction = ""
                console.warn("Odyssey ShortcutService:", root.errorMessage)
                return
            }
            root.errorMessage = ""
            root.installed = root.lastOutput.includes("MANAGED=true")
            if (action === "managed")
                SettingsStore.setShortcutsManaged(root.pendingValue)
            else if (action === "reset")
            {
                SettingsStore.resetShortcuts()
                SettingsStore.setShortcutsManaged(true)
            }
            else if (action.length > 0)
                SettingsStore.setShortcutEnabled(action, root.pendingValue)
            root.pendingAction = ""
        }
    }

    Component.onCompleted: probe()
}
