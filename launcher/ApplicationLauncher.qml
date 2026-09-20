import QtQuick
import "../services"

LauncherView {
    provider: CommandPaletteService
    placeholderText: "Search Odyssey"
    emptyText: "No matching Odyssey results"

    onActiveChanged: {
        if (active) {
            ClipboardService.refresh()
            KeybindService.refresh()
        }
    }
}
