pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool changingScheme: false
    property bool changingIntegration: false
    property bool terminalThemesEnabled: false
    property bool terminalThemesReady: false
    property string pendingScheme: ""
    property string pendingIntegration: ""
    property bool pendingIntegrationEnabled: false
    property string statusMessage: ""
    property string errorMessage: ""

    readonly property string integrationHelper:
        Quickshell.shellDir + "/scripts/manage-theme-integration.sh"
    readonly property string terminalIntegrationHelper:
        Quickshell.shellDir + "/scripts/terminal-integrations.sh"

    Component.onCompleted: refreshTerminalThemeStatus()

    function setMode(mode: string): void {
        if (SettingsStore.setAppearanceMode(mode))
            statusMessage = "Theme mode updated"
    }

    function setSurfaceOpacity(opacity: real): void {
        SettingsStore.setSurfaceOpacity(opacity)
    }

    function setAccentOverride(color: string): void {
        if (SettingsStore.setAccentOverride(color))
            statusMessage = "Accent override updated"
    }

    function clearAccentOverride(): void {
        SettingsStore.clearAccentOverride()
        statusMessage = "Wallpaper accent restored"
    }

    function setReducedMotion(enabled: bool): void {
        SettingsStore.setReducedMotion(enabled)
        statusMessage = enabled ? "Reduced motion enabled" : "Full motion enabled"
    }

    function setMotionSpeed(speed: string): void {
        if (SettingsStore.setMotionSpeed(speed))
            statusMessage = "Motion speed updated"
    }

    function setDensity(density: string): void {
        if (SettingsStore.setDensity(density))
            statusMessage = "Surface density updated"
    }

    function setCornerStyle(style: string): void {
        if (SettingsStore.setCornerStyle(style))
            statusMessage = "Corner style updated"
    }

    function setIslandMetric(metric: string, value: real): void {
        if (SettingsStore.setIslandMetric(metric, value))
            statusMessage = "Island geometry updated"
    }

    function resetIslandAndMotion(): void {
        SettingsStore.resetIslandAndMotion()
        statusMessage = "Island and motion defaults restored"
    }

    function setOdysseyPaletteEnabled(enabled: bool): void {
        SettingsStore.setWallpaperPaletteEnabled(enabled)
        statusMessage = enabled ? "Odyssey follows the wallpaper palette"
            : "Odyssey uses its built-in semantic palette"
        ThemeExportService.refresh()
    }

    function setScheme(scheme: string): void {
        if (changingScheme || SettingsStore.validSchemes.indexOf(scheme) < 0
                || scheme === Config.wallpaper.scheme)
            return
        if (!WallpaperService.currentWallpaper) {
            errorMessage = "Choose a wallpaper before changing its palette style"
            return
        }
        pendingScheme = scheme
        changingScheme = true
        errorMessage = ""
        statusMessage = "Generating palette…"
        WallpaperService.changeScheme(scheme)
    }

    function setHyprlockEnabled(enabled: bool): void {
        if (changingIntegration || enabled === Config.externalThemes.hyprlockEnabled)
            return
        pendingIntegration = "hyprlock"
        pendingIntegrationEnabled = enabled
        changingIntegration = true
        errorMessage = ""
        statusMessage = enabled ? "Enabling Hyprlock theme…"
            : "Returning Hyprlock to manual control…"
        integrationProcess.command = [integrationHelper, "hyprlock",
            enabled ? "enable" : "disable"]
        integrationProcess.running = true
    }

    function refreshTerminalThemeStatus(): void {
        if (!terminalStatusProcess.running) {
            terminalThemesReady = false
            terminalStatusOutput = ""
            terminalStatusProcess.command = [terminalIntegrationHelper, "status"]
            terminalStatusProcess.running = true
        }
    }

    function setTerminalThemesEnabled(enabled: bool): void {
        if (changingIntegration || !terminalThemesReady
                || enabled === terminalThemesEnabled)
            return
        pendingIntegration = "terminal"
        pendingIntegrationEnabled = enabled
        changingIntegration = true
        errorMessage = ""
        statusMessage = enabled ? "Enabling terminal palettes…"
            : "Returning terminal tools to manual control…"
        integrationProcess.command = [terminalIntegrationHelper,
            enabled ? "enable" : "disable"]
        integrationProcess.running = true
    }

    property Connections schemeCompletion: Connections {
        target: WallpaperService
        function onOperationStateChanged() {
            if (!root.changingScheme || WallpaperService.operationState === "changingScheme")
                return
            root.changingScheme = false
            if (WallpaperService.errorMessage.length === 0
                    && Config.wallpaper.scheme === root.pendingScheme) {
                root.statusMessage = "Palette style updated"
                root.errorMessage = ""
            } else {
                root.statusMessage = ""
                root.errorMessage = WallpaperService.errorMessage || "Palette generation failed"
            }
            root.pendingScheme = ""
        }
    }

    property string terminalStatusOutput: ""
    property Process terminalStatusProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.terminalStatusOutput = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            root.terminalThemesReady = true
            root.terminalThemesEnabled = exitCode === 0
                && root.terminalStatusOutput.indexOf(
                    "TERMINAL_THEMING=enabled") === 0
        }
    }

    property Process integrationProcess: Process {
        running: false
        stderr: StdioCollector {
            onStreamFinished: root.errorMessage = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            root.changingIntegration = false
            if (root.pendingIntegration === "terminal") {
                if (exitCode === 0) {
                    root.statusMessage = root.pendingIntegrationEnabled
                        ? "Available terminal tools follow Odyssey"
                        : "Terminal tools are under manual control"
                    root.errorMessage = ""
                    ThemeExportService.refresh()
                } else {
                    root.statusMessage = ""
                    root.errorMessage = root.errorMessage
                        || "Terminal theme ownership could not be changed"
                }
                root.pendingIntegration = ""
                root.refreshTerminalThemeStatus()
                return
            }
            if (exitCode === 0) {
                SettingsStore.setExternalTheme(root.pendingIntegration,
                    root.pendingIntegrationEnabled)
                ThemeExportService.refresh()
                root.statusMessage = root.pendingIntegrationEnabled
                    ? "Hyprlock follows Odyssey" : "Hyprlock is under manual control"
                root.errorMessage = ""
            } else {
                root.statusMessage = ""
                root.errorMessage = root.errorMessage
                    || "Integration ownership could not be changed"
            }
            root.pendingIntegration = ""
        }
    }
}
