pragma Singleton
import QtQuick
import "providers"

QtObject {
    readonly property var providers: [
        OdysseyActionsProvider,
        WorkspacesProvider,
        ClipboardProvider,
        ApplicationsProvider
    ]

    function search(queryText: string, limit: int): var {
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
        if (result?.provider === ClipboardProvider.providerId)
            return ClipboardProvider.execute(result)
        console.warn("Odyssey cannot execute an unknown palette provider:",
            result?.provider || "missing")
        return { handled: false }
    }
}
