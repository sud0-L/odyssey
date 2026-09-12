import QtQuick

LauncherView {
    provider: CommandLauncherService
    placeholderText: "Search command history or type a command"
    emptyText: "Type a command to run it in a new terminal"
    searchIcon: ""
    copyShortcutEnabled: true

    Connections {
        target: CommandLauncherService
        function onLaunchSucceeded(): void { dismissRequested() }
    }
}
