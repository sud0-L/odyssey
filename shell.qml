import Quickshell
import QtQuick
import "applications"
import "core"
import "island"
import "services"

ShellRoot {
    Component.onCompleted: {
        ShellState.start()
        ApplicationService.refresh()
        WallpaperService.refresh()
        WallpaperService.bootstrap(false)
        ThemeExportService.refresh()
    }

    Variants {
        model: Quickshell.screens

        Island {
            required property var modelData
            screen: modelData
        }
    }

}
