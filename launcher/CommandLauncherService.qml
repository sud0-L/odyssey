pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property var entries: []
    property string resolvedSource: ""
    property string historyError: ""
    property string actionError: ""
    property string actionStatus: ""
    property int revision: 0
    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/command-launcherctl.py"
    signal launchSucceeded()

    function opened(): void {
        actionError = ""
        actionStatus = ""
        refresh()
    }

    function refresh(): void {
        if (!Config.commandLauncher.historySuggestions) {
            entries = []
            historyError = ""
            revision += 1
            return
        }
        if (historyProcess.running)
            return
        historyError = ""
        historyProcess.command = [helperPath, "history",
            Config.commandLauncher.historySource, "500"]
        historyProcess.running = true
    }

    function fuzzyScore(command: string, query: string): int {
        const haystack = command.toLowerCase()
        const needle = query.toLowerCase()
        const direct = haystack.indexOf(needle)
        if (direct >= 0)
            return 1200 - direct - Math.min(command.length, 300) / 10
        let cursor = 0
        let gap = 0
        for (let index = 0; index < haystack.length && cursor < needle.length; ++index) {
            if (haystack[index] === needle[cursor])
                cursor += 1
            else if (cursor > 0)
                gap += 1
        }
        return cursor === needle.length ? 700 - gap : -1
    }

    function displayCommand(command: string, maximum: int): string {
        const compact = command.replace(/\s+/g, " ").trim()
        return compact.length > maximum
            ? compact.slice(0, Math.max(0, maximum - 3)) + "..." : compact
    }

    function result(command: string, index: int, score: real): var {
        return {
            key: "command-history:" + index,
            provider: "command-history",
            group: "Command history",
            kind: "command",
            actionId: "run-command",
            title: displayCommand(command, 82),
            subtitle: "Run in a new terminal",
            icon: "󰆍",
            iconKind: "glyph",
            badge: resolvedSource ? resolvedSource.toUpperCase() : "HISTORY",
            score: score,
            command: command,
            enabled: true
        }
    }

    function search(queryText: string, limit: int): var {
        const query = queryText.trim()
        const matches = []
        if (Config.commandLauncher.historySuggestions) {
            for (let index = 0; index < entries.length; ++index) {
                const score = query ? fuzzyScore(entries[index], query) : 1000 - index
                if (score >= 0)
                    matches.push(result(entries[index], index, score))
            }
            if (query)
                matches.sort((a, b) => b.score - a.score)
        }
        const bounded = matches.slice(0, query ? Math.max(0, limit - 1) : limit)
        if (query) {
            bounded.push({
                key: "command-typed", provider: "command-history",
                group: "Command", kind: "command-run", actionId: "run-command",
                title: `Run “${displayCommand(queryText, 68)}”`,
                subtitle: "Execute exact text in a new terminal",
                icon: "", iconKind: "glyph", badge: "RUN", score: 2000,
                command: queryText, enabled: true
            })
        }
        if (actionError || actionStatus) {
            bounded.push({
                key: "command-action-status", provider: "command-history",
                kind: "command-status", title: actionError || actionStatus,
                subtitle: actionError ? "Check the Command Launcher settings"
                    : "Nothing was executed", icon: actionError ? "󰆍" : "󰆏",
                iconKind: "glyph", badge: actionError ? "ERROR" : "COPIED",
                enabled: false, executable: false
            })
        } else if (!query && bounded.length === 0 && historyError) {
            bounded.push({
                key: "command-status", provider: "command-history",
                kind: "command-status", title: historyError,
                subtitle: "Typed commands remain available", icon: "󰆍",
                iconKind: "glyph", badge: "LOCAL", enabled: false,
                executable: false
            })
        }
        return bounded
    }

    function execute(selected, copyOnly: bool): var {
        const command = selected?.command || ""
        if (!command)
            return { handled: false }
        actionError = ""
        if (copyOnly) {
            try {
                Quickshell.clipboardText = command
                actionStatus = "Command copied"
                revision += 1
                return { handled: true, dismiss: false }
            } catch (error) {
                actionError = "Could not copy command"
                revision += 1
                return { handled: true, dismiss: false }
            }
        }
        if (launchProcess.running)
            return { handled: false }
        launchProcess.command = [helperPath, "run",
            Config.commandLauncher.terminal, command]
        launchProcess.running = true
        return { handled: true, dismiss: false }
    }

    property Process historyProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    root.entries = Array.isArray(response.entries)
                        ? response.entries : []
                    root.resolvedSource = response.source || ""
                    root.historyError = response.error || ""
                } catch (error) {
                    root.entries = []
                    root.historyError = "Shell history is unavailable"
                }
                root.revision += 1
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.entries = []
                root.historyError = "Shell history is unavailable"
                root.revision += 1
            }
        }
    }

    property Process launchProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.actionError = text.trim()
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.actionStatus = "Command launched"
                root.launchSucceeded()
            } else if (!root.actionError) {
                root.actionError = "Could not open the configured terminal"
            }
            root.revision += 1
        }
    }
}
