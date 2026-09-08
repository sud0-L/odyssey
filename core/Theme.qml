pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property var fallbackDark: ({
        primary: "#c7c3ff", onPrimary: "#2e2866",
        primaryContainer: "#46417f", onPrimaryContainer: "#e4e0ff",
        secondary: "#c8c4dc", tertiary: "#edb8c8",
        surface: "#121217", surfaceContainerLow: "#1a1a21",
        surfaceContainer: "#202027", surfaceContainerHigh: "#2a2931",
        onSurface: "#e6e1e9", onSurfaceVariant: "#c9c5cf",
        outline: "#928f99", outlineVariant: "#48464f",
        error: "#ffb4ab", warning: "#f4c46b", success: "#8bd5a5"
    })
    readonly property var fallbackLight: ({
        primary: "#5d5791", onPrimary: "#ffffff",
        primaryContainer: "#e4e0ff", onPrimaryContainer: "#19134b",
        secondary: "#605d70", tertiary: "#7a5360",
        surface: "#fcf8ff", surfaceContainerLow: "#f6f2fa",
        surfaceContainer: "#f0ecf4", surfaceContainerHigh: "#eae6ee",
        onSurface: "#1c1b20", onSurfaceVariant: "#49464f",
        outline: "#7a767f", outlineVariant: "#cbc6d0",
        error: "#ba1a1a", warning: "#805600", success: "#216e45"
    })

    property var generated: ({})
    property bool generatedAvailable: false
    property string generatedMode: "dark"

    readonly property string effectiveMode: Config.appearance.mode === "auto"
        ? (Config.appearance.wallpaperPaletteEnabled ? generatedMode : "dark")
        : Config.appearance.mode
    readonly property bool dark: effectiveMode !== "light"
    readonly property bool accentOverridden:
        Config.appearance.accentOverride.length > 0
    readonly property var colors: generatedAvailable
            && Config.appearance.wallpaperPaletteEnabled
        ? (generated[effectiveMode] || generated.dark || generated.light)
        : (dark ? fallbackDark : fallbackLight)

    readonly property color primary: accentOverridden
        ? Config.appearance.accentOverride : colorValue("primary")
    // `onPrimary`/`onSurface` collide with QML's handler-style property lookup
    // when the corresponding base token exists. Expose explicit foreground names.
    readonly property color primaryText: accentOverridden
        ? foregroundFor(primary) : colorValue("onPrimary")
    readonly property color primaryContainer: accentOverridden
        ? Qt.tint(colorValue("surfaceContainer"),
            Qt.alpha(primary, dark ? 0.34 : 0.20))
        : colorValue("primaryContainer")
    readonly property color primaryContainerText: accentOverridden
        ? primary : colorValue("onPrimaryContainer")
    readonly property color secondary: colorValue("secondary")
    readonly property color tertiary: colorValue("tertiary")
    readonly property color surface: colorValue("surface")
    readonly property color surfaceContainerLow: colorValue("surfaceContainerLow")
    readonly property color surfaceContainer: colorValue("surfaceContainer")
    readonly property color surfaceContainerHigh: colorValue("surfaceContainerHigh")
    readonly property color surfaceText: colorValue("onSurface")
    readonly property color surfaceVariantText: colorValue("onSurfaceVariant")
    readonly property color outline: colorValue("outline")
    readonly property color outlineVariant: colorValue("outlineVariant")
    readonly property color error: colorValue("error")
    readonly property color warning: colorValue("warning")
    readonly property color success: colorValue("success")

    readonly property int space1: Math.max(3,
        Math.round(4 * Config.appearance.densityScale))
    readonly property int space2: Math.max(6,
        Math.round(8 * Config.appearance.densityScale))
    readonly property int space3: Math.max(9,
        Math.round(12 * Config.appearance.densityScale))
    readonly property int space4: Math.max(12,
        Math.round(16 * Config.appearance.densityScale))
    readonly property int space5: Math.max(18,
        Math.round(24 * Config.appearance.densityScale))
    readonly property int radiusSmall: Math.round(
        8 * Config.appearance.cornerScale)
    readonly property int radiusMedium: Math.round(
        14 * Config.appearance.cornerScale)
    readonly property int radiusLarge: Math.round(
        24 * Config.appearance.cornerScale)
    readonly property int textSmall: 12
    readonly property int textBody: 14
    readonly property int textTitle: 18
    readonly property int iconSmall: 16
    readonly property int iconMedium: 20

    function colorValue(name: string): string {
        return colors && colors[name] ? colors[name]
            : (dark ? fallbackDark[name] : fallbackLight[name])
    }

    function foregroundFor(candidate: color): color {
        const luminance = 0.2126 * candidate.r + 0.7152 * candidate.g
            + 0.0722 * candidate.b
        return luminance > 0.53 ? "#17151b" : "#ffffff"
    }

    function loadPalette(text) {
    if (text === undefined)
        text = activePaletteFile.text();
        try {
            const parsed = JSON.parse(text)
            if (!parsed.dark && !parsed.light)
                throw new Error("palette requires a dark or light object")
            generated = parsed
            generatedMode = parsed.mode === "light" ? "light" : "dark"
            generatedAvailable = true
        } catch (error) {
            generated = ({})
            generatedAvailable = false
            try {
                const fallback = JSON.parse(fallbackPaletteFile.text())
                if (!fallback.dark && !fallback.light)
                    throw new Error("fallback palette requires a dark or light object")
                generated = fallback
                generatedMode = fallback.mode === "light" ? "light" : "dark"
                generatedAvailable = true
                console.warn("Odyssey: active palette unavailable; using packaged fallback:", error)
            } catch (fallbackError) {
                console.warn("Odyssey: palette fallback unavailable:", fallbackError)
            }
        }
    }

    property FileView activePaletteFile: FileView {
        path: Config.appearance.activePalettePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadPalette()
        onFileChanged: reload()
        onLoadFailed: {
            root.generated = ({})
            root.generatedAvailable = false
        }
    }

    property FileView fallbackPaletteFile: FileView {
        path: Config.appearance.fallbackPalettePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!root.generatedAvailable)
                root.loadPalette(fallbackPaletteFile.text())
        }
        onFileChanged: {
            reload()
            if (!root.generatedAvailable)
                root.loadPalette(fallbackPaletteFile.text())
        }
    }
}
