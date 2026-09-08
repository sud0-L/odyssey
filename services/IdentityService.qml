pragma Singleton
import QtCore
import QtQuick
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property url personalImageSource: Config.appearance.brandMarkSource
    property bool loaded: false
    readonly property bool hasPersonalImage:
        personalImageSource.toString().length > 0

    function setPersonalImage(source): bool {
        const value = source?.toString().trim() || ""
        if (!value.startsWith("file:")) {
            console.warn("Odyssey rejected a non-local personal image")
            return false
        }

        personalImageSource = value
        identityFile.setText(JSON.stringify({ personalImage: value }, null, 2))
        return true
    }

    function loadIdentity(raw): void {
        try {
            const parsed = JSON.parse(raw)
            const value = parsed?.personalImage?.toString().trim() || ""
            if (value.startsWith("file:"))
                personalImageSource = value
        } catch (error) {
            console.warn("Odyssey could not parse personal identity settings:",
                error)
        }
        loaded = true
    }

    property FileView identityFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
            + "/odyssey-identity.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadIdentity(text())
        onLoadFailed: error => {
            root.loaded = true
            if (error !== FileViewError.FileNotFound)
                console.warn("Odyssey could not load personal identity settings:",
                    FileViewError.toString(error))
        }
        onSaveFailed: error => console.warn(
            "Odyssey could not save personal identity settings:",
            FileViewError.toString(error))
    }
}
