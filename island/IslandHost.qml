import QtQuick
import Quickshell
import "../core"

// Recreate the small layer surface when crossing the compositor blur boundary.
// Persistent services remain live; AppearanceService restores its page after
// this short compositor-boundary swap.
Scope {
    id: host
    required property var screen

    Loader {
        id: islandLoader
        sourceComponent: SurfaceMaterial.glass
            ? glassIsland : solidIsland
    }

    Component {
        id: solidIsland
        Island {
            screen: host.screen
            glassLayer: false
        }
    }

    Component {
        id: glassIsland
        Island {
            screen: host.screen
            glassLayer: true
        }
    }
}
