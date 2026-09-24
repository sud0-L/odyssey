import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components"
import "../core"
import "../services"

PanelWindow {
    id: window

    property bool panelOpen: false
    property bool glassLayer: false
    signal closeRequested()

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool presentationTarget:
        HyprlandService.shouldPresentOn(monitor)
    readonly property int bodyHeight: Math.round(Math.max(
        Config.notes.minimumHeight, Math.min(Config.notes.maximumHeight,
            window.height * Config.notes.heightRatio)))
    readonly property real attachedShoulder: attachedSurface.shoulderWidth

    anchors.top: true
    anchors.right: true
    anchors.bottom: true
    implicitWidth: Config.notes.width + Theme.space3 * 2
    color: "transparent"
    visible: presentationTarget
    exclusiveZone: 0
    mask: Region {
        shape: RegionShape.Rect
        x: 0
        y: 0
        width: window.panelOpen ? window.width : 0
        height: window.panelOpen ? window.height : 0
    }

    WlrLayershell.namespace: glassLayer
        ? "odyssey:notes:glass" : "odyssey:notes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panelOpen
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [window]
        active: window.panelOpen
        onCleared: window.closeRequested()
    }

    Item {
        id: panelSurface
        x: window.panelOpen
            ? (Config.appearance.islandAttached
                ? window.width - width : Theme.space3)
            : window.width + Theme.space2
        y: Math.round((window.height - height) / 2)
        width: Config.notes.width
        height: window.bodyHeight + (Config.appearance.islandAttached
            ? attachedShoulder * 2 : 0)

        Surface {
            anchors.fill: parent
            visible: !Config.appearance.islandAttached
            radius: Theme.radiusLarge
            border.width: Config.island.borderEnabled
                ? Config.island.borderThickness : 0
            solidColor: Qt.alpha(notesPanel.confirmDelete
                    ? Qt.darker(Theme.surfaceContainer, 1.85)
                    : Theme.surfaceContainer,
                Config.appearance.surfaceOpacity)
            solidBorderColor: Qt.alpha(Theme.outlineVariant,
                Theme.dark ? 0.66 : 0.52)
        }

        EdgeAttachedSurface {
            id: attachedSurface
            anchors.fill: parent
            visible: Config.appearance.islandAttached
            radius: Theme.radiusLarge
            outlineWidth: Config.island.borderEnabled
                ? Config.island.borderThickness : 0
            fillColor: Qt.alpha(notesPanel.confirmDelete
                    ? Qt.darker(Theme.surfaceContainer, 1.85)
                    : Theme.surfaceContainer,
                Config.appearance.surfaceOpacity)
            outlineColor: Qt.alpha(Theme.outlineVariant,
                Theme.dark ? 0.66 : 0.52)
        }

        NotesPanel {
            id: notesPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.space4
            anchors.rightMargin: Theme.space4
            anchors.topMargin: Theme.space4
                + (Config.appearance.islandAttached ? attachedShoulder : 0)
            anchors.bottomMargin: Theme.space4
                + (Config.appearance.islandAttached ? attachedShoulder : 0)
            active: window.panelOpen
            onCloseRequested: window.closeRequested()
        }

        Behavior on x {
            NumberAnimation {
                duration: Config.animations.surfaceMorph
                easing.type: Animations.emphasizedEase
            }
        }
    }
}
