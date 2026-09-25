pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Sole owner of the serialized awww lifecycle and wallpaper/palette transaction.
QtObject {
    id: root

    property var wallpapers: []
    property string currentWallpaper: ""
    property string pendingWallpaper: ""
    property string pendingScheme: ""
    property string pendingThemeSourceMode: ""
    property string pendingThemeSourceColor: ""
    property bool pendingRememberCustomColor: false
    property string candidateWallpaper: ""
    property string candidateToken: ""
    property string candidateStatus: ""
    property bool candidateReady: false
    property string pendingMonitorName: ""
    property bool directApplyPending: false
    property string directRenderOutput: ""
    property string directRenderError: ""
    property string directPaletteOutput: ""
    property string directPaletteError: ""
    property string directPaletteToken: ""
    property string queuedPaletteToken: ""
    property var queuedPaletteCommand: []
    property bool loading: false
    property bool applying: false
    property bool backendAvailable: false
    property string backendKind: "awww"
    property string backendState: "starting"
    property string backendDetail: "Checking awww…"
    property string operationState: "idle"
    property string operationKind: ""
    property string operationOutput: ""
    property string operationError: ""
    property string errorMessage: ""
    property bool cancelAfterExit: false
    property bool paletteAvailable: Theme.generatedAvailable

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/wallpaperctl.sh"
    readonly property string homeDirectory: Quickshell.env("HOME")
    readonly property var searchPaths: Config.wallpaper.directories.map(path =>
        path.startsWith("/") ? path : homeDirectory + "/" + path)
    readonly property string currentName: displayName(currentWallpaper)
    readonly property bool busy: operationProcess.running
        || directRenderProcess.running
    readonly property string statusLabel: errorMessage
        || (backendState !== "ready" ? backendDetail
        : candidateReady ? "Candidate palette prepared — Apply to change Odyssey"
        : currentWallpaper ? currentName : "No wallpaper selected")

    signal wallpaperApplied(string path, bool paletteUpdated)

    function displayName(path: string): string {
        const name = path.substring(path.lastIndexOf("/") + 1)
            .replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ")
        return name.replace(/\b\w/g, character => character.toUpperCase())
    }

    function imageSource(path: string): string {
        return path ? "file://" + path.split("/").map(encodeURIComponent)
            .join("/") : ""
    }

    function filterWallpapers(query: string): var {
        const normalized = query.trim().toLowerCase()
        return !normalized ? wallpapers : wallpapers.filter(item =>
            item.name.toLowerCase().includes(normalized)
                || item.path.toLowerCase().includes(normalized))
    }

    function setTarget(target: string): bool {
        return SettingsStore.setWallpaperTarget(target)
    }

    function setGalleryColumns(columns: int): bool {
        return SettingsStore.setWallpaperGalleryColumns(columns)
    }

    function setRefreshOnOpen(enabled: bool): void {
        SettingsStore.setWallpaperRefreshOnOpen(enabled)
    }

    function setTransition(transition: string): bool {
        return SettingsStore.setWallpaperTransition(transition)
    }

    function setTransitionDuration(duration: real): bool {
        return SettingsStore.setWallpaperTransitionDuration(duration)
    }

    function resetPreferences(): void {
        SettingsStore.resetWallpaper()
    }

    function beginOperation(kind: string, command: var): bool {
        if (operationProcess.running)
            return false
        operationKind = kind
        operationOutput = ""
        operationError = ""
        operationProcess.command = command
        operationProcess.running = true
        return true
    }

    function refresh(): void {
        if (discoveryProcess.running)
            return
        loading = true
        discoveryProcess.command = [helperPath, "list"].concat(searchPaths)
        discoveryProcess.running = true
    }

    function bootstrap(manual: bool): void {
        if (busy || applying)
            return
        backendState = manual ? "recovering" : "starting"
        backendAvailable = false
        backendDetail = manual ? "Retrying Odyssey's awww renderer…"
            : "Starting Odyssey's awww renderer…"
        errorMessage = ""
        beginOperation("bootstrap", [helperPath, "bootstrap",
            manual ? "manual" : "auto"])
    }

    function retry(): void {
        bootstrap(true)
    }

    function selectCandidate(path: string): bool {
        if (busy || applying || directPaletteProcess.running
                || queuedPaletteCommand.length > 0
                || !wallpapers.some(item => item.path === path))
            return false
        candidateReady = false
        candidateWallpaper = path
        candidateToken = String(Date.now()) + "-" + Math.random()
        candidateStatus = "Generating local palette…"
        errorMessage = ""
        operationState = "previewing"
        return beginOperation("candidate", [helperPath, "candidate", path,
            Config.wallpaper.scheme, candidateToken,
            Config.appearance.themeSourceMode,
            Config.appearance.themeSourceColor])
    }

    // Render a gallery choice first. Palette extraction is deliberately a
    // separate, stale-safe background operation so large images do not delay
    // the visible wallpaper transition.
    function applyWallpaper(path: string, monitorName: string): bool {
        if (busy || applying || !wallpapers.some(item => item.path === path))
            return false
        const names = outputNames(monitorName)
        if (!names) {
            errorMessage = "No live display available"
            return false
        }
        candidateToken = String(Date.now()) + "-apply-" + Math.random()
        candidateStatus = "Applying wallpaper…"
        pendingWallpaper = path
        pendingMonitorName = monitorName
        directApplyPending = true
        errorMessage = ""
        operationState = "applying"
        applying = true
        directRenderOutput = ""
        directRenderError = ""
        directRenderProcess.command = [helperPath, "render", path,
            Config.wallpaper.scheme, Config.wallpaper.target, names,
            Config.wallpaper.transition,
            String(Config.wallpaper.transitionDuration),
            Config.appearance.reducedMotion ? "true" : "false", candidateToken,
            Config.appearance.themeSourceMode,
            Config.appearance.themeSourceColor]
        directRenderProcess.running = true
        return true
    }

    function queuePalette(path: string, token: string): void {
        queuedPaletteCommand = [helperPath, "palette", path,
            Config.wallpaper.scheme, token, Config.appearance.themeSourceMode,
            Config.appearance.themeSourceColor]
        queuedPaletteToken = token
        if (!directPaletteProcess.running)
            startQueuedPalette()
    }

    function startQueuedPalette(): void {
        if (queuedPaletteCommand.length === 0)
            return
        directPaletteOutput = ""
        directPaletteError = ""
        directPaletteToken = queuedPaletteToken
        queuedPaletteToken = ""
        directPaletteProcess.command = queuedPaletteCommand
        queuedPaletteCommand = []
        directPaletteProcess.running = true
    }

    function clearCandidateState(): void {
        candidateWallpaper = ""
        candidateToken = ""
        candidateReady = false
        candidateStatus = ""
    }

    function cancelCandidate(): void {
        if (applying)
            return
        clearCandidateState()
        operationState = "idle"
        if (busy) {
            cancelAfterExit = true
            operationProcess.running = false
            return
        }
        beginOperation("cancel", [helperPath, "cancel-candidate"])
    }

    function outputNames(monitorName: string): string {
        return Config.wallpaper.target === "all"
            ? HyprlandService.connectedMonitors.map(monitor => monitor.name)
                .filter(Boolean).join(",") : monitorName
    }

    function applyCandidate(monitorName: string): bool {
        if (!candidateReady || !backendAvailable || busy || applying
                || directPaletteProcess.running
                || queuedPaletteCommand.length > 0)
            return false
        const names = outputNames(monitorName)
        if (!names) {
            errorMessage = "No live display available"
            return false
        }
        applying = true
        operationState = "applying"
        pendingWallpaper = candidateWallpaper
        errorMessage = ""
        return beginOperation("apply", [helperPath, "apply",
            candidateWallpaper, Config.wallpaper.scheme,
            Config.wallpaper.target, names, Config.wallpaper.transition,
            String(Config.wallpaper.transitionDuration),
            Config.appearance.reducedMotion ? "true" : "false",
            candidateToken, Config.appearance.themeSourceMode,
            Config.appearance.themeSourceColor])
    }

    function changeScheme(scheme: string): void {
        if (scheme === Config.wallpaper.scheme || busy || applying
                || directPaletteProcess.running
                || queuedPaletteCommand.length > 0
                || (Config.appearance.themeSourceMode === "wallpaper"
                    && !currentWallpaper))
            return
        pendingScheme = scheme
        if (Config.appearance.themeSourceMode === "color") {
            candidateToken = String(Date.now()) + "-color-scheme"
            errorMessage = ""
            operationState = "changingScheme"
            beginOperation("colorScheme", [helperPath, "theme-source", "color",
                Config.appearance.themeSourceColor, currentWallpaper,
                scheme, candidateToken])
            return
        }
        candidateWallpaper = currentWallpaper
        candidateToken = String(Date.now()) + "-scheme"
        candidateReady = false
        candidateStatus = "Generating local palette…"
        errorMessage = ""
        operationState = "changingScheme"
        beginOperation("schemeCandidate", [helperPath, "candidate",
            currentWallpaper, scheme, candidateToken,
            Config.appearance.themeSourceMode,
            Config.appearance.themeSourceColor])
    }

    function changeThemeSource(mode: string, color: string,
            rememberCustom: bool): bool {
        const normalized = SettingsStore.normalizedThemeColor(color)
        if (busy || applying || directPaletteProcess.running
                || queuedPaletteCommand.length > 0
                || (mode === "wallpaper" && !currentWallpaper)
                || (mode !== "wallpaper" && mode !== "color")
                || (mode === "color" && !normalized))
            return false
        if (mode === Config.appearance.themeSourceMode
                && (mode === "wallpaper"
                    || normalized === Config.appearance.themeSourceColor)) {
            if (mode === "color" && rememberCustom)
                SettingsStore.setThemeSourceColor(normalized, true)
            return false
        }
        pendingThemeSourceMode = mode
        pendingThemeSourceColor = mode === "color" ? normalized : ""
        pendingRememberCustomColor = rememberCustom
        candidateToken = String(Date.now()) + "-theme-source"
        errorMessage = ""
        operationState = "changingThemeSource"
        return beginOperation("themeSource", [helperPath, "theme-source",
            pendingThemeSourceMode, pendingThemeSourceColor,
            currentWallpaper, Config.wallpaper.scheme, candidateToken])
    }

    function parseStatus(text: string): void {
        for (const line of text.split("\n")) {
            if (line.startsWith("CURRENT="))
                currentWallpaper = line.substring(8)
            if (!line.startsWith("STATE="))
                continue
            backendState = line.substring(6)
            backendAvailable = backendState === "ready"
            if (backendState === "ready")
                backendDetail = "awww renderer ready"
            else if (backendState === "recovering")
                backendDetail = "Recovering Odyssey's awww renderer…"
            else if (backendState === "missing")
                backendDetail = "awww is required for Odyssey wallpapers (sudo pacman -S awww)"
            else if (backendState === "conflict")
                backendDetail = "Another wallpaper renderer is active; stop or reconfigure it first"
            else if (backendState === "exhausted")
                backendDetail = "Automatic awww recovery paused after three attempts — Retry manually"
            else
                backendDetail = "awww is unavailable; Retry to check again"
        }
    }

    function requestHealthProbe(): void {
        if (!busy && !applying)
            beginOperation("probe", [helperPath, "probe"])
    }

    function finishOperation(exitCode: int): void {
        const kind = operationKind
        const output = operationOutput
        const detail = operationError.trim()
        parseStatus(output)
        operationKind = ""

        if (cancelAfterExit) {
            cancelAfterExit = false
            pendingScheme = ""
            errorMessage = ""
            Qt.callLater(() => beginOperation("cancel",
                [helperPath, "cancel-candidate"]))
            return
        }

        if (kind === "bootstrap") {
            if (exitCode !== 0) {
                backendAvailable = false
                if (backendState === "starting" || backendState === "recovering")
                    backendState = "unavailable"
                errorMessage = detail || backendDetail
            } else {
                backendState = "ready"
                backendAvailable = true
                backendDetail = "awww renderer ready"
                errorMessage = ""
            }
            operationState = "idle"
            return
        }

        if (kind === "probe") {
            if (backendState === "ready") {
                backendAvailable = true
                return
            }
            backendAvailable = false
            if (backendState !== "missing" && backendState !== "conflict"
                    && backendState !== "exhausted")
                Qt.callLater(() => bootstrap(false))
            return
        }

        if (kind === "candidate" || kind === "directCandidate"
                || kind === "schemeCandidate") {
            if (exitCode !== 0) {
                candidateReady = false
                candidateStatus = "Palette preparation failed"
                errorMessage = detail || "Palette generation failed"
                pendingScheme = ""
                pendingWallpaper = ""
                pendingMonitorName = ""
                directApplyPending = false
                clearCandidateState()
                operationState = "idle"
                return
            }
            candidateReady = true
            candidateStatus = "Palette prepared locally"
            if (kind === "schemeCandidate") {
                candidateStatus = "Verifying renderer before palette publication…"
                Qt.callLater(() => beginOperation("scheme", [helperPath,
                    "scheme", candidateWallpaper, pendingScheme,
                    candidateToken, Config.appearance.themeSourceMode,
                    Config.appearance.themeSourceColor]))
            } else if (kind === "directCandidate") {
                candidateStatus = "Applying wallpaper…"
                Qt.callLater(() => root.applyCandidate(root.pendingMonitorName))
            } else {
                operationState = "ready"
            }
            return
        }

        if (kind === "apply" || kind === "scheme") {
            const committed = exitCode === 0 && output.includes("COMMITTED=true")
            applying = false
            pendingWallpaper = ""
            pendingMonitorName = ""
            if (committed) {
                const appliedPath = currentWallpaper
                paletteAvailable = true
                if (kind === "scheme")
                    SettingsStore.setScheme(pendingScheme)
                clearCandidateState()
                pendingScheme = ""
                directApplyPending = false
                errorMessage = ""
                operationState = "idle"
                wallpaperApplied(appliedPath, true)
            } else {
                errorMessage = detail || "Wallpaper transaction failed; previous state was restored"
                if (kind === "scheme" || directApplyPending) {
                    pendingScheme = ""
                    clearCandidateState()
                    Qt.callLater(() => beginOperation("cancel",
                        [helperPath, "cancel-candidate"]))
                }
                directApplyPending = false
                operationState = "idle"
                recoveryTimer.restart()
            }
            return
        }

        if (kind === "themeSource") {
            const committed = exitCode === 0 && output.includes("COMMITTED=true")
            if (committed) {
                if (pendingThemeSourceMode === "wallpaper")
                    SettingsStore.setThemeSourceWallpaper()
                else
                    SettingsStore.setThemeSourceColor(
                        pendingThemeSourceColor, pendingRememberCustomColor)
                paletteAvailable = true
                errorMessage = ""
            } else {
                errorMessage = detail || "Theme source generation failed"
            }
            pendingThemeSourceMode = ""
            pendingThemeSourceColor = ""
            pendingRememberCustomColor = false
            operationState = "idle"
            return
        }

        if (kind === "colorScheme") {
            const committed = exitCode === 0 && output.includes("COMMITTED=true")
            if (committed) {
                SettingsStore.setScheme(pendingScheme)
                paletteAvailable = true
                errorMessage = ""
            } else {
                errorMessage = detail || "Palette generation failed"
            }
            pendingScheme = ""
            operationState = "idle"
            return
        }

        if (kind === "cancel") {
            operationState = "idle"
            if (exitCode !== 0)
                errorMessage = detail || "Candidate cleanup failed"
        }
    }

    property Process discoveryProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                const seen = new Set()
                for (const line of text.split("\n")) {
                    const path = line.trim()
                    if (path && !seen.has(path)) {
                        seen.add(path)
                        rows.push({
                            path: path,
                            name: root.displayName(path),
                            source: root.imageSource(path)
                        })
                    }
                }
                root.wallpapers = rows
            }
        }
        onExited: exitCode => {
            root.loading = false
            if (exitCode !== 0)
                root.errorMessage = "Wallpaper scan failed"
        }
    }

    property Process operationProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.operationOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.operationError = text
        }
        onExited: exitCode => root.finishOperation(exitCode)
    }

    property Process directRenderProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.directRenderOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.directRenderError = text
        }
        onExited: exitCode => {
            const output = root.directRenderOutput
            root.parseStatus(output)
            root.applying = false
            root.pendingMonitorName = ""
            if (exitCode === 0 && output.includes("COMMITTED=true")) {
                const appliedPath = root.pendingWallpaper
                root.currentWallpaper = appliedPath
                root.pendingWallpaper = ""
                root.directApplyPending = false
                root.errorMessage = ""
                root.operationState = "idle"
                root.wallpaperApplied(appliedPath, false)
                root.queuePalette(appliedPath, root.candidateToken)
            } else {
                root.pendingWallpaper = ""
                root.directApplyPending = false
                root.operationState = "idle"
                root.errorMessage = root.directRenderError.trim()
                    || "Wallpaper rendering failed; previous wallpaper was restored"
                root.recoveryTimer.restart()
            }
        }
    }

    property Process directPaletteProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.directPaletteOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.directPaletteError = text
        }
        onExited: exitCode => {
            const current = root.directPaletteToken === root.candidateToken
            const committed = exitCode === 0
                && root.directPaletteOutput.includes("COMMITTED=true")
            if (current && committed) {
                root.paletteAvailable = true
                root.errorMessage = ""
                root.wallpaperApplied(root.currentWallpaper,
                    root.directPaletteOutput.includes("PALETTE=updated"))
            } else if (current && exitCode !== 0
                    && !root.directPaletteError.includes("stale palette request")) {
                root.errorMessage = root.directPaletteError.trim()
                    || "Wallpaper changed, but palette generation failed"
            }
            Qt.callLater(() => root.startQueuedPalette())
        }
    }

    property Timer healthTimer: Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.requestHealthProbe()
    }

    property Timer recoveryTimer: Timer {
        interval: 300
        onTriggered: root.requestHealthProbe()
    }
}
