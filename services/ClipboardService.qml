pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property var entries: []
    property bool available: false
    property bool loading: false
    property bool refreshPending: false
    property string errorMessage: ""
    property string currentText: Quickshell.clipboardText
    property string currentKind: currentText.trim().length > 0 ? "text" : "unknown"
    property string currentImageFormat: ""
    property bool presentationActive: false
    property string previewDirectory: ""
    property int presentationGeneration: 0
    property int previewRevision: 0
    property int previewCount: 0
    property var previewSources: ({})
    property var previewQueue: []
    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/clipboardctl.sh"

    signal copied(string entryId)
    signal removed(string entryId)
    signal cleared()

    readonly property string currentPreview: normalizeText(currentText, 180)

    function normalizeText(value: string, maximum: int): string {
        const compact = (value || "").replace(/\s+/g, " ").trim()
        return compact.length > maximum ? compact.slice(0, maximum - 1) + "…" : compact
    }

    function imageEntry(id: string, format: string, byteSize: int,
            width: int, height: int): var {
        const label = "Image · " + format.toUpperCase() + " · " + width + " × " + height
        return { id: id, kind: "image", format: format, byteSize: byteSize,
            width: width, height: height, preview: label,
            search: "image " + format + " " + width + " " + height,
            previewEligible: byteSize <= Config.clipboard.previewMaxBytes
                && width <= Config.clipboard.previewMaxDimension
                && height <= Config.clipboard.previewMaxDimension
                && width * height <= Config.clipboard.previewMaxPixels }
    }

    function parseEntries(output: string): var {
        const parsed = []
        for (const line of output.split("\n")) {
            const separator = line.indexOf("\t")
            if (separator <= 0)
                continue
            const id = line.slice(0, separator).trim()
            const raw = line.slice(separator + 1).trim()
            if (!/^\d+$/.test(id) || !raw)
                continue
            const binary = raw.match(/^\[\[ binary data ([0-9]+(?:\.[0-9]+)?) (B|KiB|MiB) (png|jpe?g|webp) ([0-9]+)x([0-9]+) \]\]$/i)
            if (binary) {
                const unit = binary[2]
                const multiplier = unit === "MiB" ? 1024 * 1024 : unit === "KiB" ? 1024 : 1
                const byteSize = Number(binary[1]) * multiplier
                const width = Number(binary[4])
                const height = Number(binary[5])
                const format = binary[3].toLowerCase() === "jpg" ? "jpeg" : binary[3].toLowerCase()
                if (Number.isSafeInteger(byteSize) && byteSize > 0 && Number.isSafeInteger(width)
                        && Number.isSafeInteger(height) && width > 0 && height > 0)
                    parsed.push(imageEntry(id, format, Math.round(byteSize), width, height))
            } else if (!raw.startsWith("[[ binary data")) {
                const preview = normalizeText(raw, 240)
                if (preview)
                    parsed.push({ id: id, kind: "text", preview: preview, search: preview })
            }
            if (parsed.length >= Config.clipboard.historyLimit)
                break
        }
        return parsed
    }

    function refresh(): void {
        if (listProcess.running) {
            refreshPending = true
            return
        }
        loading = true
        errorMessage = ""
        listProcess.running = true
    }

    function copy(entryId: string): bool {
        if (!/^\d+$/.test(entryId) || actionProcess.running)
            return false
        actionProcess.action = "copy"
        actionProcess.entryId = entryId
        actionProcess.command = [helperPath, "copy", entryId]
        actionProcess.running = true
        return true
    }

    function remove(entryId: string): bool {
        if (!/^\d+$/.test(entryId) || actionProcess.running)
            return false
        actionProcess.action = "delete"
        actionProcess.entryId = entryId
        actionProcess.command = [helperPath, "delete", entryId]
        actionProcess.running = true
        return true
    }

    function clearHistory(): bool {
        if (actionProcess.running)
            return false
        actionProcess.action = "wipe"
        actionProcess.entryId = ""
        actionProcess.command = [helperPath, "wipe"]
        actionProcess.running = true
        return true
    }

    function beginPresentation(): void {
        presentationGeneration += 1
        presentationActive = true
        previewCount = 0
        previewSources = ({})
        previewQueue = []
        currentKind = currentText.trim().length > 0 ? "text" : "checking"
        sessionProcess.generation = presentationGeneration
        sessionProcess.command = [helperPath, "open-preview-session"]
        sessionProcess.running = true
    }

    function endPresentation(): void {
        presentationGeneration += 1
        presentationActive = false
        previewQueue = []
        previewSources = ({})
        previewRevision += 1
        currentImageFormat = ""
        if (thumbnailProcess.running)
            thumbnailProcess.signal(15)
        if (previewDirectory) {
            closeProcess.command = [helperPath, "close-preview-session", previewDirectory]
            closeProcess.running = true
            previewDirectory = ""
        }
    }

    function thumbnailSource(key: string): string {
        previewRevision
        return previewSources[key] || ""
    }

    function requestPreview(entry): void {
        if (!presentationActive || !previewDirectory || !entry || entry.kind !== "image"
                || !entry.previewEligible || previewSources[entry.id]
                || previewCount >= Config.clipboard.previewLimit)
            return
        if (previewQueue.some(item => item.id === entry.id)
                || (thumbnailProcess.running && thumbnailProcess.key === entry.id))
            return
        previewQueue = previewQueue.concat([entry])
        startNextPreview()
    }

    function startNextPreview(): void {
        if (!presentationActive || thumbnailProcess.running || !previewDirectory
                || previewCount >= Config.clipboard.previewLimit || previewQueue.length === 0)
            return
        const entry = previewQueue[0]
        previewQueue = previewQueue.slice(1)
        thumbnailProcess.key = entry.id
        thumbnailProcess.generation = presentationGeneration
        thumbnailProcess.command = [helperPath, "thumbnail", entry.id, entry.format,
            String(entry.byteSize), String(entry.width), String(entry.height), previewDirectory,
            entry.id + ".png", String(Config.clipboard.previewMaxBytes),
            String(Config.clipboard.previewMaxDimension), String(Config.clipboard.previewMaxPixels),
            String(Config.clipboard.thumbnailWidth), String(Config.clipboard.thumbnailHeight)]
        thumbnailProcess.running = true
    }

    function probeCurrent(): void {
        if (!presentationActive || currentText.trim().length > 0 || !previewDirectory
                || currentProbe.running)
            return
        currentProbe.generation = presentationGeneration
        currentProbe.command = [helperPath, "probe-current", previewDirectory, "current.png",
            String(Config.clipboard.previewMaxBytes), String(Config.clipboard.previewMaxDimension),
            String(Config.clipboard.previewMaxPixels), String(Config.clipboard.thumbnailWidth),
            String(Config.clipboard.thumbnailHeight)]
        currentProbe.running = true
    }

    onCurrentTextChanged: {
        currentKind = currentText.trim().length > 0 ? "text" : "unknown"
        if (presentationActive && currentText.trim().length === 0)
            probeCurrent()
    }

    Component.onCompleted: refresh()

    property Process listProcess: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = root.parseEntries(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorMessage = text.trim()
            }
        }
        onExited: exitCode => {
            root.loading = false
            root.available = exitCode === 0
            if (exitCode !== 0 && !root.errorMessage)
                root.errorMessage = "Clipboard history is unavailable"
            if (root.refreshPending) {
                root.refreshPending = false
                Qt.callLater(() => root.refresh())
            }
        }
    }

    property Process actionProcess: Process {
        property string action: ""
        property string entryId: ""
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorMessage = text.trim()
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                if (action === "copy") root.copied(entryId)
                else if (action === "delete") root.removed(entryId)
                else if (action === "wipe") root.cleared()
                root.refresh()
            } else if (!root.errorMessage) {
                root.errorMessage = action === "copy"
                    ? "Could not restore clipboard entry"
                    : action === "delete" ? "Could not remove clipboard entry"
                    : "Could not clear clipboard history"
            }
        }
    }

    property Process sessionProcess: Process {
        property int generation: 0
        stdout: StdioCollector {
            onStreamFinished: {
                const directory = text.trim()
                if (root.presentationActive && sessionProcess.generation === root.presentationGeneration
                        && directory.startsWith("/")) {
                    root.previewDirectory = directory
                    root.probeCurrent()
                    root.startNextPreview()
                }
            }
        }
    }

    property Process thumbnailProcess: Process {
        property string key: ""
        property int generation: 0
        onExited: exitCode => {
            if (exitCode === 0 && root.presentationActive
                    && generation === root.presentationGeneration && root.previewDirectory) {
                const updated = Object.assign({}, root.previewSources)
                updated[key] = "file://" + root.previewDirectory + "/" + key + ".png"
                root.previewSources = updated
                root.previewCount += 1
                root.previewRevision += 1
            }
            root.startNextPreview()
        }
    }

    property Process currentProbe: Process {
        property int generation: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.presentationActive || currentProbe.generation !== root.presentationGeneration
                        || root.currentText.trim().length > 0)
                    return
                const image = /^kind=image$/m.test(text)
                root.currentKind = image ? "image" : /^kind=unsupported$/m.test(text)
                    ? "unsupported" : "empty"
                if (image && root.previewCount < Config.clipboard.previewLimit && root.previewDirectory) {
                    const updated = Object.assign({}, root.previewSources)
                    updated.current = "file://" + root.previewDirectory + "/current.png"
                    root.previewSources = updated
                    root.previewCount += 1
                    root.previewRevision += 1
                    const format = text.match(/^format=(.+)$/m)
                    root.currentImageFormat = format ? format[1].toUpperCase() : "IMAGE"
                }
            }
        }
    }

    property Process closeProcess: Process { }
}
