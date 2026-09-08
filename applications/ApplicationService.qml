pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var applications: []
    property var usage: ({})
    property bool usageLoaded: false
    readonly property int count: applications.length

    function text(value): string {
        return (value || "").toString().toLowerCase()
    }

    function refresh(): void {
        const entries = DesktopEntries.applications.values || []
        const visible = []
        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i]
            if (!entry.noDisplay)
                visible.push(entry)
        }
        visible.sort((a, b) => a.name.localeCompare(b.name))
        applications = visible
        cleanupUsage()
    }

    function usageFor(entry): var {
        return entry?.id ? (usage[entry.id] || null) : null
    }

    function isRecent(entry): bool {
        return usageFor(entry) !== null
    }

    function usageBoost(entry): int {
        const data = usageFor(entry)
        if (!data)
            return 0
        const countBoost = Math.min(60, (data.count || 1) * 6)
        const ageHours = Math.max(0, (Date.now() - (data.lastUsed || 0)) / 3600000)
        const recencyBoost = Math.max(0, 40 - Math.floor(ageHours / 6))
        return countBoost + recencyBoost
    }

    function compareUsage(a, b): int {
        const aUsage = usageFor(a)
        const bUsage = usageFor(b)
        if (aUsage && bUsage) {
            if (aUsage.lastUsed !== bUsage.lastUsed)
                return bUsage.lastUsed - aUsage.lastUsed
            if (aUsage.count !== bUsage.count)
                return bUsage.count - aUsage.count
        } else if (aUsage) {
            return -1
        } else if (bUsage) {
            return 1
        }
        return a.name.localeCompare(b.name)
    }

    function primaryCategory(entry): string {
        const categories = entry?.categories || []
        const labels = [
            ["TerminalEmulator", "Terminal"],
            ["WebBrowser", "Browser"],
            ["FileManager", "Files"],
            ["Development", "Development"],
            ["Game", "Games"],
            ["AudioVideo", "Media"],
            ["Graphics", "Graphics"],
            ["Network", "Network"],
            ["Settings", "Settings"],
            ["Office", "Office"],
            ["Education", "Education"],
            ["Security", "Security"],
            ["System", "System"],
            ["Utility", "Utility"]
        ]
        for (const pair of labels) {
            if (categories.indexOf(pair[0]) >= 0)
                return pair[1]
        }
        return ""
    }

    function launchWorkingDirectory(entry): string {
        const requested = entry?.workingDirectory?.trim() || ""
        if (requested)
            return requested
        const home = Quickshell.env("HOME")
        if (home)
            return home.toString()
        const homeUrl = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        return decodeURIComponent(homeUrl.replace(/^file:\/\//, ""))
    }

    function fuzzyScore(needle: string, value: string): int {
        const candidate = text(value)
        if (!candidate)
            return -1
        if (candidate === needle)
            return 1000
        if (candidate.startsWith(needle))
            return 800 - candidate.length

        const substring = candidate.indexOf(needle)
        if (substring >= 0)
            return 600 - substring * 4 - candidate.length

        let score = 0
        let previous = -2
        let cursor = 0
        for (let i = 0; i < candidate.length && cursor < needle.length; ++i) {
            if (candidate[i] !== needle[cursor])
                continue
            score += i === previous + 1 ? 18 : 7
            if (i === 0 || candidate[i - 1] === " " || candidate[i - 1] === "-")
                score += 12
            previous = i
            cursor += 1
        }
        return cursor === needle.length ? score - candidate.length : -1
    }

    function find(query: string): var {
        const needle = text(query).trim()
        if (!needle)
            return applications.slice().sort((a, b) => compareUsage(a, b))

        const matches = []
        for (const entry of applications) {
            const nameScore = fuzzyScore(needle, entry.name)
            const genericScore = fuzzyScore(needle, entry.genericName) - 80
            const commentScore = fuzzyScore(needle, entry.comment) - 160
            const categoryScore = fuzzyScore(needle,
                (entry.categories || []).join(" ")) - 100
            const keywordScore = fuzzyScore(needle,
                (entry.keywords || []).join(" ")) - 120
            const identityScore = fuzzyScore(needle,
                `${entry.id || ""} ${entry.startupClass || ""}`) - 140
            const baseScore = Math.max(nameScore, genericScore, commentScore,
                categoryScore, keywordScore, identityScore)
            if (baseScore >= 0)
                matches.push({ entry, score: baseScore + usageBoost(entry) })
        }
        matches.sort((a, b) => b.score - a.score
            || a.entry.name.localeCompare(b.entry.name))
        return matches.map(match => match.entry)
    }

    function launch(entry): void {
        if (entry && !entry.noDisplay && entry.command?.length > 0) {
            recordUsage(entry)
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: launchWorkingDirectory(entry)
            })
        }
    }

    function recordUsage(entry): void {
        if (!entry?.id)
            return
        const updated = Object.assign({}, usage)
        const previous = updated[entry.id] || {}
        updated[entry.id] = {
            count: (previous.count || 0) + 1,
            lastUsed: Date.now()
        }
        usage = updated
        if (usageLoaded)
            usageFile.setText(JSON.stringify({ applications: usage }, null, 2))
    }

    function loadUsage(content: string): void {
        try {
            const parsed = content?.trim() ? JSON.parse(content) : {}
            usage = parsed.applications || {}
            usageLoaded = true
            cleanupUsage()
        } catch (error) {
            usageLoaded = true
            console.warn("Odyssey could not parse application usage history:", error)
        }
    }

    function cleanupUsage(): void {
        if (!usageLoaded || applications.length === 0)
            return
        const availableIds = new Set(applications.map(entry => entry.id))
        const cleaned = {}
        let changed = false
        for (const id in usage) {
            if (availableIds.has(id))
                cleaned[id] = usage[id]
            else
                changed = true
        }
        if (changed) {
            usage = cleaned
            usageFile.setText(JSON.stringify({ applications: usage }, null, 2))
        }
    }

    property Connections desktopEntryConnections: Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { root.refresh() }
    }

    property FileView usageFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
            + "/odyssey-app-usage.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadUsage(text())
        onLoadFailed: error => {
            root.usageLoaded = true
            if (error !== FileViewError.FileNotFound)
                console.warn("Odyssey could not load application usage history:",
                    FileViewError.toString(error))
        }
        onSaveFailed: error => console.warn(
            "Odyssey could not save application usage history:",
            FileViewError.toString(error))
    }
}
