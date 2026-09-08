pragma Singleton
import QtQuick
import "../../core"
import "../../services"

QtObject {
    readonly property string providerId: "workspaces"
    readonly property string displayName: "Workspaces"
    readonly property int priority: 90

    function requestedWorkspaceId(queryText: string): int {
        const needle = queryText.trim().toLowerCase()
        const match = needle.match(/^(?:(?:workspace|ws)\s*|(?:switch|go)(?:\s+to)?(?:\s+workspace)?\s+)?(\d{1,2})$/)
        if (!match)
            return 0
        const id = Number(match[1])
        return Number.isInteger(id) && id >= 1
            && id <= Config.hyprland.workspaceCount ? id : 0
    }

    function requestsWorkspaceList(queryText: string): bool {
        const needle = queryText.trim().toLowerCase()
        if (needle.length < 2)
            return false
        return "workspace".startsWith(needle)
            || needle === "ws"
            || needle === "switch workspace"
            || needle === "go to workspace"
    }

    function resultFor(workspaceId: int, score: int): var {
        const workspace = HyprlandService.workspaceById(workspaceId)
        const current = HyprlandService.activeWorkspaceId === workspaceId
        const urgent = workspace?.urgent ?? false
        const windowCount = HyprlandService.workspaceWindowCount(workspace)
        const monitorName = workspace?.monitor?.name || ""
        const state = current ? "Current"
            : urgent ? "Urgent"
            : windowCount > 0 ? "Occupied" : "Empty"
        const windowLabel = windowCount === 1 ? "1 window"
            : `${windowCount} windows`
        const subtitle = windowCount > 0
            ? `${windowLabel}${monitorName ? ` · ${monitorName}` : ""}`
            : "Open an empty workspace"

        return {
            key: `workspace:${workspaceId}`,
            provider: providerId,
            group: displayName,
            kind: "workspace",
            actionId: "switch-workspace",
            title: `Workspace ${workspaceId}`,
            subtitle: subtitle,
            icon: current ? "󰮯" : urgent ? "󰀦" : "󰍹",
            iconKind: "glyph",
            badge: state,
            score: score,
            workspaceId: workspaceId,
            enabled: true
        }
    }

    function query(queryText: string, limit: int): var {
        const requestedId = requestedWorkspaceId(queryText)
        if (requestedId > 0)
            return [resultFor(requestedId, 1300)]
        if (!requestsWorkspaceList(queryText))
            return []

        const results = []
        for (let id = 1; id <= Config.hyprland.workspaceCount; ++id) {
            const workspace = HyprlandService.workspaceById(id)
            const current = HyprlandService.activeWorkspaceId === id
            const urgent = workspace?.urgent ?? false
            const occupied = HyprlandService.workspaceWindowCount(workspace) > 0
            const stateBoost = current ? 180 : urgent ? 140 : occupied ? 80 : 0
            results.push(resultFor(id, 900 + stateBoost - id))
        }
        results.sort((left, right) => right.score - left.score
            || left.workspaceId - right.workspaceId)
        return results.slice(0, limit)
    }

    function execute(result): var {
        if (result?.actionId !== "switch-workspace"
                || !Number.isInteger(result.workspaceId))
            return { handled: false }
        const handled = HyprlandService.activateWorkspace(result.workspaceId)
        return { handled: handled, dismiss: handled }
    }
}
