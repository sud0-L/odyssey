import QtQuick
import "../services"

LauncherView {
    provider: CommandPaletteService
    placeholderText: "Search Odyssey"
    emptyText: "No matching Odyssey results"

    onVisibleChanged: {
        if (visible) {
            ClipboardService.refresh()
            KeybindService.refresh()
        }
    }
}
