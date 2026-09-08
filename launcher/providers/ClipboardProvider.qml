pragma Singleton
import QtQuick
import "../../services"

QtObject {
    readonly property string providerId: "clipboard"
    readonly property string displayName: "Clipboard"
    readonly property int priority: 85

    function query(queryText: string, limit: int): var {
        const needle = queryText.trim().toLowerCase()
        const listRequested = needle === "clipboard" || needle === "clip"
        if (!listRequested && needle.length < 2)
            return []
        const matches = []
        for (let i = 0; i < ClipboardService.entries.length; ++i) {
            const entry = ClipboardService.entries[i]
            const position = entry.preview.toLowerCase().indexOf(needle)
            if (!listRequested && position < 0)
                continue
            matches.push({
                key: `clipboard:${entry.id}`,
                provider: providerId,
                group: displayName,
                kind: "clipboard",
                actionId: "copy-clipboard-entry",
                title: entry.preview,
                subtitle: "Copy this text back to the clipboard",
                icon: "󰅌",
                iconKind: "glyph",
                badge: "Clipboard",
                score: (listRequested ? 860 : 980 - position) - i,
                entryId: entry.id,
                enabled: ClipboardService.available
            })
            if (matches.length >= limit)
                break
        }
        return matches
    }

    function execute(result): var {
        const handled = result?.entryId
            ? ClipboardService.copy(result.entryId) : false
        return { handled: handled, dismiss: handled }
    }
}
