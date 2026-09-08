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
    property string candidateWallpaper: ""
    property string candidateToken: ""
    property string candidateStatus: ""
    property bool candidateReady: false
    property string pendingMonitorName: ""
    property bool directApplyPending: false
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
        if (busy || applying || !wallpapers.some(item => item.path === path))
            return false
        candidateReady = false
        candidateWallpaper = path
        candidateToken = String(Date.now()) + "-" + Math.random()
        candidateStatus = "Generating local palette…"
        errorMessage = ""
        operationState = "previewing"
        return beginOperation("candidate", [helperPath, "candidate", path,
            Config.wallpaper.scheme, candidateToken])
    }

    // A gallery choice is a commit request, not a UI preview. The helper still
    // prepares an isolated candidate first, so palette validation and the
    // atomic renderer/palette transaction retain their rollback boundary.
    function applyWallpaper(path: string, monitorName: string): bool {
        if (busy || applying || !wallpapers.some(item => item.path === path))
            return false
        const names = outputNames(monitorName)
        if (!names) {
            errorMessage = "No live display available"
            return false
        }
        candidateReady = false
        candidateWallpaper = path
        candidateToken = String(Date.now()) + "-apply-" + Math.random()
        candidateStatus = "Preparing wallpaper transaction…"
        pendingWallpaper = path
        pendingMonitorName = monitorName
        directApplyPending = true
        errorMessage = ""
        operationState = "preparing"
        return beginOperation("directCandidate", [helperPath, "candidate", path,
            Config.wallpaper.scheme, candidateToken])
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
        if (!candidateReady || !backendAvailable || busy || applying)
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
            candidateToken])
    }

    function changeScheme(scheme: string): void {
        if (scheme === Config.wallpaper.scheme || busy || applying
                || !currentWallpaper)
            return
        pendingScheme = scheme
        candidateWallpaper = currentWallpaper
        candidateToken = String(Date.now()) + "-scheme"
        candidateReady = false
        candidateStatus = "Generating local palette…"
        errorMessage = ""
        operationState = "changingScheme"
        beginOperation("schemeCandidate", [helperPath, "candidate",
            currentWallpaper, scheme, candidateToken])
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
                    candidateToken]))
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
