pragma Singleton
import QtQuick
import "providers"

QtObject {
    readonly property var providers: [
        OdysseyActionsProvider,
        WorkspacesProvider,
        KeybindsProvider,
        ClipboardProvider,
        ApplicationsProvider
    ]

    function search(queryText: string, limit: int): var {
        // A keybind-list query is a dedicated, scrollable catalogue rather
        // than a handful of results competing with other providers.
        if (KeybindsProvider.isListQuery(queryText))
            return KeybindsProvider.query(queryText, 1024)
        const combined = []
        for (const provider of providers) {
            const providerResults = provider.query(queryText, limit)
            for (const result of providerResults) {
                result.providerPriority = provider.priority
                combined.push(result)
            }
        }
        combined.sort((a, b) => b.score - a.score
            || b.providerPriority - a.providerPriority
            || a.title.localeCompare(b.title))
        return combined.slice(0, limit)
    }

    function execute(result): var {
        if (result?.provider === ApplicationsProvider.providerId)
            return ApplicationsProvider.execute(result)
        if (result?.provider === OdysseyActionsProvider.providerId)
            return OdysseyActionsProvider.execute(result)
        if (result?.provider === WorkspacesProvider.providerId)
            return WorkspacesProvider.execute(result)
        if (result?.provider === KeybindsProvider.providerId)
            return KeybindsProvider.execute(result)
        if (result?.provider === ClipboardProvider.providerId)
            return ClipboardProvider.execute(result)
        console.warn("Odyssey cannot execute an unknown palette provider:",
            result?.provider || "missing")
        return { handled: false }
    }
}
