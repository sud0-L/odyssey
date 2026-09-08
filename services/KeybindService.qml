pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var entries: []
    property bool loading: false
    property bool available: false
    property bool refreshPending: false
    property string errorMessage: ""
    property string collectedOutput: ""

    function refresh(): void {
        if (query.running) {
            refreshPending = true
            return
        }
        loading = true
        errorMessage = ""
        collectedOutput = ""
        query.running = true
    }

    function modifierNames(mask: int): var {
        const names = []
        if (mask & 64) names.push("Super")
        if (mask & 4) names.push("Ctrl")
        if (mask & 8) names.push("Alt")
        if (mask & 1) names.push("Shift")
        if (mask & 2) names.push("Caps")
        if (mask & 16) names.push("Mod2")
        if (mask & 32) names.push("Mod3")
        if (mask & 128) names.push("Mod5")
        return names
    }

    function keyName(binding): string {
        const key = String(binding.key || "").trim()
        if (key.length > 0)
            return key.length === 1 ? key.toUpperCase() : key
        const code = Number(binding.keycode)
        if (Number.isInteger(code) && code >= 0)
            return `code:${code}`
        return binding.catch_all === true ? "Any key" : "Unknown key"
    }

    function chord(binding): string {
        return modifierNames(Number(binding.modmask) || 0)
            .concat([keyName(binding)]).join(" + ")
    }

    function fallbackTitle(dispatcher: string, argument: string): string {
        if (dispatcher === "__lua")
            return "Hyprland Lua binding"
        const names = {
            exec: "Run command",
            workspace: "Switch workspace",
            movetoworkspace: "Move window to workspace",
            movetoworkspacesilent: "Move window silently to workspace",
            killactive: "Close active window",
            togglefloating: "Toggle floating window",
            fullscreen: "Toggle fullscreen",
            togglespecialworkspace: "Toggle special workspace",
            movefocus: "Move focus",
            movewindow: "Move window",
            resizeactive: "Resize active window"
        }
        const base = names[dispatcher.toLowerCase()]
            || dispatcher.replace(/[-_]/g, " ").replace(/^./,
                character => character.toUpperCase())
            || "Hyprland binding"
        return argument.length > 0 ? `${base}: ${argument}` : base
    }

    function normalize(raw): var {
        const dispatcher = String(raw.dispatcher || "").trim()
        const argument = String(raw.arg || "").trim()
        const description = String(raw.description || "").trim()
        const submap = String(raw.submap || "").trim()
        const keys = chord(raw)
        const flags = []
        if (raw.release === true) flags.push("on release")
        if (raw.repeat === true) flags.push("repeatable")
        if (raw.longPress === true || raw.long_press === true)
            flags.push("long press")
        if (raw.mouse === true) flags.push("mouse")
        // Hyprland exposes Lua callbacks as __lua plus an internal callback id.
        // That id is neither stable nor meaningful to a user, so descriptions
        // are the only action metadata we display and index for Lua bindings.
        const operation = dispatcher === "__lua" ? ""
            : [dispatcher, argument].filter(value => value).join(" ")
        const context = []
        if (submap.length > 0) context.push(`Submap: ${submap}`)
        if (operation.length > 0) context.push(operation)
        if (flags.length > 0) context.push(flags.join(", "))
        const title = description || fallbackTitle(dispatcher, argument)
        return {
            chord: keys,
            title: title,
            subtitle: context.join(" · ") || "Active Hyprland binding",
            dispatcher: dispatcher,
            argument: argument,
            description: description,
            submap: submap,
            terms: (`${title} ${keys} ${dispatcher === "__lua" ? "" : dispatcher}`
                + ` ${dispatcher === "__lua" ? "" : argument} ${submap}`)
                .toLowerCase()
        }
    }

    function parse(output: string): var {
        let raw
        try {
            raw = JSON.parse(output)
        } catch (error) {
            throw new Error("Hyprland returned invalid keybinding data")
        }
        if (!Array.isArray(raw))
            throw new Error("Hyprland returned invalid keybinding data")
        const normalized = []
        const seen = new Set()
        for (let i = 0; i < raw.length && normalized.length < 1024; ++i) {
            if (!raw[i] || typeof raw[i] !== "object")
                continue
            const entry = normalize(raw[i])
            const identity = `${entry.submap}\u0000${entry.chord}\u0000`
                + `${entry.dispatcher}\u0000${entry.argument}\u0000${entry.description}`
            if (seen.has(identity))
                continue
            seen.add(identity)
            normalized.push(entry)
        }
        normalized.sort((left, right) => left.chord.localeCompare(right.chord)
            || left.title.localeCompare(right.title))
        return normalized
    }

    property Process query: Process {
        command: ["hyprctl", "binds", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.collectedOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorMessage = text.trim()
            }
        }
        onExited: exitCode => {
            root.loading = false
            if (exitCode === 0) {
                try {
                    root.entries = root.parse(root.collectedOutput)
                    root.available = true
                    root.errorMessage = ""
                } catch (error) {
                    root.entries = []
                    root.available = false
                    root.errorMessage = error.message
                }
            } else {
                root.entries = []
                root.available = false
                if (!root.errorMessage)
                    root.errorMessage = "Active Hyprland keybindings are unavailable"
            }
            if (root.refreshPending) {
                root.refreshPending = false
                Qt.callLater(() => root.refresh())
            }
        }
    }

    Component.onCompleted: refresh()
}
