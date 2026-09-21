pragma Singleton
import QtQuick

// Shared material tokens for every top-level Odyssey surface. Glass is kept
// compositor-first: QML supplies tint, luminosity and edge depth while
// Hyprland supplies the backdrop blur for the dedicated layer namespace.
QtObject {
    id: root

    readonly property bool glass: Config.appearance.material === "glass"
    readonly property real glassOpacity: Math.max(0.54, Math.min(0.70,
        0.30 + Config.appearance.surfaceOpacity * 0.40))
    readonly property color tint: Qt.alpha(Theme.primary,
        Theme.dark ? 0.11 : 0.075)
    readonly property color glassBase: Qt.alpha(
        Qt.tint(Theme.surfaceContainer, tint), glassOpacity)
    readonly property color glassOutline: Qt.alpha(
        Qt.tint(Theme.outlineVariant, Qt.alpha("#ffffff",
            Theme.dark ? 0.22 : 0.40)), Theme.dark ? 0.76 : 0.68)
    readonly property color innerHighlight: Qt.alpha("#ffffff",
        Theme.dark ? 0.24 : 0.52)
    readonly property color depthEdge: Qt.alpha("#000000",
        Theme.dark ? 0.24 : 0.12)
    readonly property color compactHighlight: Qt.alpha(
        Qt.tint("#ffffff", Qt.alpha(Theme.primary,
            Theme.dark ? 0.20 : 0.12)), Theme.dark ? 0.42 : 0.60)
    readonly property color compactDepthEdge: Qt.alpha(
        Qt.tint("#000000", Qt.alpha(Theme.primary, 0.08)),
        Theme.dark ? 0.30 : 0.15)

    function fill(solidColor: color, compactness): color {
        if (!glass)
            return solidColor
        const compact = Number.isFinite(Number(compactness))
            ? Math.max(0, Math.min(1, Number(compactness))) : 0
        const compactTint = Qt.alpha(Theme.primary,
            compact * (Theme.dark ? 0.09 : 0.055))
        const base = Qt.tint(glassBase, compactTint)
        const opacity = glassOpacity - compact * 0.09
        // Preserve state/accent tints from callers without letting an opaque
        // source color defeat the material translucency.
        return Qt.alpha(Qt.tint(base, Qt.alpha(solidColor, 0.16)), opacity)
    }

    function outline(solidColor: color): color {
        return glass
            ? Qt.tint(glassOutline, Qt.alpha(solidColor, 0.18)) : solidColor
    }
}
