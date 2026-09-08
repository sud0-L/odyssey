pragma Singleton
import QtQuick
import "../../services"

QtObject {
    readonly property string providerId: "keybinds"
    readonly property string displayName: "Keybindings"
    readonly property int priority: 88
    readonly property var listTerms: [
        "keybinds", "keybind", "shortcuts", "shortcut", "hotkeys", "hotkey",
        "bindings", "binding"
    ]

    function requestsList(needle: string): bool {
        if (needle.length < 2)
            return false
        return listTerms.some(term => term === needle || term.startsWith(needle))
    }

    function isListQuery(queryText: string): bool {
        return requestsList(queryText.trim().toLowerCase())
    }

    function matchScore(needle: string, entry): int {
        const title = entry.title.toLowerCase()
        const chord = entry.chord.toLowerCase()
        if (title === needle || chord === needle)
            return 1180
        if (title.startsWith(needle) || chord.startsWith(needle))
            return 1080
        const position = entry.terms.indexOf(needle)
        if (position >= 0)
            return 980 - Math.min(position, 80)
        const tokens = needle.split(/\s+/)
        return tokens.every(token => entry.terms.indexOf(token) >= 0)
            ? 880 : -1
    }

    function statusResult(title: string, subtitle: string): var {
        return [{
            key: "keybinds:status",
            provider: providerId,
            group: displayName,
            kind: "keybind",
            title: title,
            subtitle: subtitle,
            icon: "󰌌",
            iconKind: "glyph",
            badge: "Keybindings",
            score: 1000,
            enabled: false,
            executable: false
        }]
    }

    function query(queryText: string, limit: int): var {
        const needle = queryText.trim().toLowerCase()
        const listRequested = requestsList(needle)
        if (!listRequested && needle.length < 2)
            return []
        if (listRequested && KeybindService.loading)
            return statusResult("Loading active keybindings…",
                "Reading the current Hyprland binding table")
        if (listRequested && !KeybindService.available)
            return statusResult("Keybindings unavailable",
                KeybindService.errorMessage || "Could not query Hyprland")

        const matches = []
        for (let i = 0; i < KeybindService.entries.length; ++i) {
            const entry = KeybindService.entries[i]
            const score = listRequested ? 920 - i : matchScore(needle, entry)
            if (score < 0)
                continue
            matches.push({
                key: `keybind:${entry.submap}:${entry.chord}:${i}`,
                provider: providerId,
                group: displayName,
                kind: "keybind",
                title: entry.title,
                subtitle: entry.subtitle,
                icon: "󰌌",
                iconKind: "glyph",
                badge: entry.chord,
                score: score,
                enabled: true,
                executable: false
            })
        }
        matches.sort((left, right) => right.score - left.score
            || left.title.localeCompare(right.title))
        return matches.slice(0, limit)
    }

    function execute(result): var {
        return { handled: false }
    }
}
