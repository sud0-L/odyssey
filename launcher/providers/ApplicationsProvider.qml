pragma Singleton
import QtQuick
import "../../applications"

QtObject {
    readonly property string providerId: "applications"
    readonly property string displayName: "Applications"
    readonly property int priority: 80

    function query(queryText: string, limit: int): var {
        const entries = ApplicationService.find(queryText)
        const results = []
        const bounded = Math.min(limit, entries.length)
        const emptyQuery = queryText.trim().length === 0
        for (let i = 0; i < bounded; ++i) {
            const entry = entries[i]
            const category = ApplicationService.primaryCategory(entry)
            const recent = emptyQuery && ApplicationService.isRecent(entry)
            results.push({
                key: `application:${entry.id}`,
                provider: providerId,
                group: displayName,
                kind: "application",
                actionId: "launch-application",
                title: entry.name,
                subtitle: entry.comment || entry.genericName || "Launch application",
                icon: entry.icon || "",
                iconKind: "theme",
                badge: recent ? "Recent" : (category || "Application"),
                score: (emptyQuery ? 600 : 900) - i,
                application: entry,
                enabled: true
            })
        }
        return results
    }

    function execute(result): var {
        if (!result?.application)
            return { handled: false }
        ApplicationService.launch(result.application)
        return { handled: true, dismiss: true }
    }
}
