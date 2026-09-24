import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../services"

Scope {
    id: host
    required property var screen
    property bool opened: false

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool presentationTarget:
        HyprlandService.shouldPresentOn(monitor)

    Loader {
        sourceComponent: SurfaceMaterial.glass ? glassWindow : solidWindow
    }

    Component {
        id: solidWindow
        NotesWindow {
            screen: host.screen
            panelOpen: host.opened
            glassLayer: false
            onCloseRequested: host.opened = false
        }
    }

    Component {
        id: glassWindow
        NotesWindow {
            screen: host.screen
            panelOpen: host.opened
            glassLayer: true
            onCloseRequested: host.opened = false
        }
    }

    onPresentationTargetChanged: {
        if (!presentationTarget)
            opened = false
    }

    Connections {
        target: ShellActions
        function onNotesToggleRequested(): void {
            if (host.presentationTarget)
                host.opened = !host.opened
        }
        function onNotesOpenRequested(): void {
            if (host.presentationTarget)
                host.opened = true
        }
        function onNotesCloseRequested(): void {
            host.opened = false
        }
        function onNewNoteRequested(): void {
            if (host.presentationTarget) {
                host.opened = true
                NotesService.createNote()
            }
        }
    }
}
