pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property QtObject appearance: QtObject {
        readonly property string mode: {
            const candidate = SettingsStore.value("appearance", "mode", "dark")
            return SettingsStore.validModes.indexOf(candidate) >= 0
                ? candidate : "dark"
        }
        readonly property string fontFamily: "Adwaita Sans"
        readonly property string monoFontFamily: "JetBrainsMono Nerd Font"
        // Optional packaged default; user selection is persisted by IdentityService.
        readonly property url brandMarkSource: ""
        readonly property string stateRoot: {
            const configured = Quickshell.env("XDG_STATE_HOME") || ""
            return configured.length > 0 ? configured
                : Quickshell.env("HOME") + "/.local/state"
        }
        // Runtime palettes are mutable user state; this packaged file is fallback only.
        readonly property string activePalettePath: stateRoot + "/odyssey/palette.json"
        readonly property string fallbackPalettePath: Qt.resolvedUrl("../generated/palette.json")
        readonly property real surfaceOpacity: SettingsStore.numberValue(
            "appearance", "surfaceOpacity", 0.96, 0.72, 1)
        readonly property string accentOverride: {
            const candidate = SettingsStore.value("appearance",
                "accentOverride", "")
            return typeof candidate === "string"
                    && /^#[0-9a-fA-F]{6}$/.test(candidate)
                ? candidate.toLowerCase() : ""
        }
        readonly property bool reducedMotion: SettingsStore.boolValue(
            "appearance", "reducedMotion", false)
        readonly property string motionSpeed: {
            const candidate = SettingsStore.value("appearance", "motionSpeed",
                "balanced")
            return SettingsStore.validMotionSpeeds.indexOf(candidate) >= 0
                ? candidate : "balanced"
        }
        readonly property real motionScale: motionSpeed === "quick" ? 0.76
            : motionSpeed === "calm" ? 1.28 : 1
        readonly property string density: {
            const candidate = SettingsStore.value("appearance", "density",
                "balanced")
            return SettingsStore.validDensities.indexOf(candidate) >= 0
                ? candidate : "balanced"
        }
        readonly property real densityScale: density === "compact" ? 0.86
            : density === "airy" ? 1.12 : 1
        readonly property string cornerStyle: {
            const candidate = SettingsStore.value("appearance", "cornerStyle",
                "balanced")
            return SettingsStore.validCornerStyles.indexOf(candidate) >= 0
                ? candidate : "balanced"
        }
        readonly property real cornerScale: cornerStyle === "subtle" ? 0.72
            : cornerStyle === "round" ? 1.22 : 1
        readonly property bool wallpaperPaletteEnabled: SettingsStore.boolValue(
            "appearance", "wallpaperPaletteEnabled", true)
        readonly property bool use24HourClock: SettingsStore.boolValue(
            "appearance", "use24HourClock", true)
    }

    readonly property QtObject island: QtObject {
        readonly property int topMargin: SettingsStore.numberValue(
            "island", "topMargin", 5, 0, 16)
        // topMargin + reservedSpace keeps four pixels below the 26 px pill.
        readonly property int reservedSpace: SettingsStore.numberValue(
            "island", "reservedSpace", 30, 26, 52)
        readonly property int dormantWidth: SettingsStore.numberValue(
            "island", "dormantWidth", 214, 214, 320)
        readonly property int dormantHeight: 28
        readonly property bool restScaleSynced: SettingsStore.boolValue(
            "island", "restScaleSynced", true)
        readonly property real restTextScale: SettingsStore.numberValue(
            "island", "restTextScale", 100, 80, 130) / 100
        readonly property real restIconScale: SettingsStore.numberValue(
            "island", "restIconScale", 100, 80, 130) / 100
        readonly property real restContentScale: Math.max(
            restTextScale, restIconScale)
        readonly property int restItemSpacing: SettingsStore.numberValue(
            "island", "restItemSpacing", 8, 2, 18)
        readonly property var restItemOrder: SettingsStore.stringListValue(
            "island", "restItemOrder", SettingsStore.validRestIslandItems,
            SettingsStore.validRestIslandItems)
        readonly property bool restShowWeather: restItemOrder.indexOf("Weather") >= 0
        readonly property bool restShowDnd: restItemOrder.indexOf("Dnd") >= 0
        readonly property bool restShowKeepAwake:
            restItemOrder.indexOf("KeepAwake") >= 0
        readonly property bool restShowPowerProfile:
            restItemOrder.indexOf("PowerProfile") >= 0
        readonly property int restMinimumWidth: Math.round(
            214 * restContentScale)
        readonly property bool hoverScaleSynced: SettingsStore.boolValue(
            "island", "hoverScaleSynced", true)
        readonly property real hoverTextScale: SettingsStore.numberValue(
            "island", "hoverTextScale", 100, 80, 130) / 100
        readonly property real hoverIconScale: SettingsStore.numberValue(
            "island", "hoverIconScale", 100, 80, 130) / 100
        readonly property real hoverContentScale: Math.max(
            hoverTextScale, hoverIconScale)
        readonly property int hoverItemSpacing: SettingsStore.numberValue(
            "island", "hoverItemSpacing", 8, 2, 20)
        readonly property var hoverItemOrder: SettingsStore.stringListValue(
            "island", "hoverItemOrder", SettingsStore.validHoverIslandItems,
            SettingsStore.validHoverIslandItems)
        readonly property bool hoverShowWorkspaces:
            hoverItemOrder.indexOf("Workspaces") >= 0
        readonly property bool hoverShowClock: hoverItemOrder.indexOf("Clock") >= 0
        readonly property bool hoverShowMedia: hoverItemOrder.indexOf("Media") >= 0
        readonly property bool hoverShowAudio: hoverItemOrder.indexOf("Audio") >= 0
        readonly property bool hoverShowNetwork:
            hoverItemOrder.indexOf("Network") >= 0
        readonly property bool hoverShowDnd: hoverItemOrder.indexOf("Dnd") >= 0
        readonly property bool hoverShowBluetooth:
            hoverItemOrder.indexOf("Bluetooth") >= 0
        readonly property bool hoverShowKeepAwake:
            hoverItemOrder.indexOf("KeepAwake") >= 0
        readonly property bool hoverShowBattery:
            hoverItemOrder.indexOf("Battery") >= 0
        readonly property int hoverMinimumWidth: Math.round(
            470 * hoverContentScale)
        readonly property int hoverMediaMinimumWidth: hoverMinimumWidth
        readonly property int hoverWidth: SettingsStore.numberValue(
            "island", "hoverWidth", 470, 470, 760)
        readonly property int hoverHeight: 54
        readonly property int expandedWidth: SettingsStore.numberValue(
            "island", "expandedWidth", 789, 620, 900)
        readonly property int expandedHeight: 300
        readonly property int osdWidth: 360
        readonly property int osdHeight: 72
        readonly property int mediaWidth: 460
        readonly property int mediaHeight: 88
        readonly property int collapseDelay: 420
        readonly property bool autoHide: SettingsStore.boolValue(
            "island", "autoHide", false)
        readonly property int autoHideDelay: SettingsStore.numberValue(
            "island", "autoHideDelay", 1800, 500, 10000)
        readonly property bool showRevealLip: SettingsStore.boolValue(
            "island", "showRevealLip", true)
        readonly property int revealHeight: 4
        readonly property int osdTimeout: 1800
        readonly property bool hideInFullscreen: true
    }

    readonly property QtObject idle: QtObject {
        readonly property bool managed: SettingsStore.boolValue(
            "idle", "managed", true)
        readonly property int dimMinutes: SettingsStore.numberValue(
            "idle", "dimMinutes", 5, 1, 999)
        readonly property int lockMinutes: SettingsStore.numberValue(
            "idle", "lockMinutes", 10, 1, 999)
        readonly property int displayOffMinutes: SettingsStore.numberValue(
            "idle", "displayOffMinutes", 12, 1, 999)
        readonly property int suspendMinutes: SettingsStore.numberValue(
            "idle", "suspendMinutes", 30, 1, 999)
        readonly property int hibernateMinutes: SettingsStore.numberValue(
            "idle", "hibernateMinutes", 90, 1, 999)
        readonly property int dimPercent: SettingsStore.numberValue(
            "idle", "dimPercent", 10, 5, 90)
        readonly property bool powerSoundsEnabled: SettingsStore.boolValue(
            "idle", "powerSoundsEnabled", false)
    }

    readonly property QtObject audio: QtObject {
        readonly property int maxVolumePercent: 100
    }

    readonly property QtObject controlCenter: QtObject {
        readonly property int detailExpandedHeight: 560
        readonly property int detailHeight: 244
        readonly property int detailResultLimit: 4
        readonly property int detailAnimation: 340
        readonly property int levelConfirmationTimeout: 600
    }

    readonly property QtObject system: QtObject {
        readonly property int metricsInterval: 2000
        readonly property int temperatureInterval: 5000
        readonly property int storageInterval: 30000
        readonly property string temperaturePath: "/sys/class/thermal/thermal_zone0/temp"
        readonly property string storagePath: "/"
    }

    readonly property QtObject animations: QtObject {
        readonly property int fast: root.appearance.reducedMotion ? 1
            : Math.round(150 * root.appearance.motionScale)
        readonly property int normal: root.appearance.reducedMotion ? 1
            : Math.round(220 * root.appearance.motionScale)
        readonly property int large: root.appearance.reducedMotion ? 1
            : Math.round(300 * root.appearance.motionScale)
        readonly property int surfaceMorph: root.appearance.reducedMotion ? 1
            : Math.round(340 * root.appearance.motionScale)
        readonly property int profileMorph: root.appearance.reducedMotion ? 1
            : Math.round(340 * root.appearance.motionScale)
        readonly property int profileFeedbackRise: root.appearance.reducedMotion ? 1
            : Math.round(220 * root.appearance.motionScale)
        readonly property int profileFeedbackHold: root.appearance.reducedMotion ? 1
            : Math.round(300 * root.appearance.motionScale)
        readonly property int profileFeedbackSettle: root.appearance.reducedMotion ? 1
            : Math.round(260 * root.appearance.motionScale)
        readonly property int profileFeedbackFade: root.appearance.reducedMotion ? 1
            : Math.round(480 * root.appearance.motionScale)
    }

    readonly property QtObject insights: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int pageTransition: 220
        readonly property int hourlyPreviewCount: 12
        readonly property int dailyPreviewCount: 7
    }

    readonly property QtObject dashboard: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int transition: 220
        readonly property bool showHero: SettingsStore.boolValue(
            "dashboard", "showHero", true)
        readonly property bool showMedia: SettingsStore.boolValue(
            "dashboard", "showMedia", true)
        readonly property bool showSystem: SettingsStore.boolValue(
            "dashboard", "showSystem", true) || !showMedia
        readonly property bool showQuickStrip: SettingsStore.boolValue(
            "dashboard", "showQuickStrip", true)
    }

    readonly property QtObject notifications: QtObject {
        readonly property bool enabled: true
        readonly property bool takeOverServer: true
        readonly property bool showPopups: SettingsStore.boolValue(
            "notifications", "showPopups", true)
        readonly property bool allowCriticalAlerts: SettingsStore.boolValue(
            "notifications", "allowCriticalAlerts", true)
        readonly property int timeout: SettingsStore.numberValue(
            "notifications", "timeout", 5000, 2000, 10000)
        readonly property int criticalTimeout: SettingsStore.numberValue(
            "notifications", "criticalTimeout", 9000, 4000, 15000)
        readonly property int historyLimit: SettingsStore.numberValue(
            "notifications", "historyLimit", 50, 20, 100)
        readonly property bool doNotDisturb: SettingsStore.boolValue(
            "notifications", "doNotDisturb", false)
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
    }

    readonly property QtObject launcher: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int resultLimit: 24
    }

    readonly property QtObject commandLauncher: QtObject {
        readonly property string historySource: {
            const candidate = SettingsStore.value("commandLauncher",
                "historySource", "auto")
            return SettingsStore.validCommandHistorySources.indexOf(candidate) >= 0
                ? candidate : "auto"
        }
        readonly property string terminal: {
            const candidate = SettingsStore.value("commandLauncher",
                "terminal", "auto")
            return SettingsStore.validCommandTerminals.indexOf(candidate) >= 0
                ? candidate : "auto"
        }
        readonly property bool historySuggestions: SettingsStore.boolValue(
            "commandLauncher", "historySuggestions", true)
    }

    readonly property QtObject hyprland: QtObject {
        // Matches the numeric workspace bindings discovered on this machine.
        readonly property int workspaceCount: 10
    }

    readonly property QtObject displays: QtObject {
        readonly property string islandPolicy: {
            const candidate = SettingsStore.value("displays", "islandPolicy", "all")
            return SettingsStore.validIslandPolicies.indexOf(candidate) >= 0
                ? candidate : "all"
        }
        readonly property string primaryMonitor: {
            const candidate = SettingsStore.value("displays", "primaryMonitor", "auto")
            return typeof candidate === "string"
                && /^(auto|[A-Za-z0-9._:-]+)$/.test(candidate)
                ? candidate : "auto"
        }
    }

    readonly property QtObject media: QtObject {
        readonly property bool enabled: SettingsStore.boolValue(
            "media", "enabled", true)
        readonly property bool preferPlaying: SettingsStore.boolValue(
            "media", "preferPlaying", true)
        readonly property int presentationTimeout: SettingsStore.numberValue(
            "media", "presentationTimeout", 4200, 2000, 10000)
        readonly property string hoverMode: {
            const candidate = SettingsStore.value("media", "hoverMode", "playing")
            return SettingsStore.validMediaHoverModes.indexOf(candidate) >= 0
                ? candidate : "playing"
        }
        readonly property int positionInterval: 1000
    }

    readonly property QtObject clipboard: QtObject {
        readonly property int historyLimit: 100
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        // Presentation-only limits. These are intentionally not user settings:
        // clipboard previews are sensitive, short-lived, and bounded.
        readonly property int previewLimit: 12
        readonly property int previewMaxBytes: 8 * 1024 * 1024
        readonly property int previewMaxDimension: 4096
        readonly property int previewMaxPixels: 16 * 1000 * 1000
        readonly property int thumbnailWidth: 160
        readonly property int thumbnailHeight: 100
    }

    readonly property QtObject capture: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int frameRate: 60
        readonly property int shellClearDelay: root.animations.fast
            + root.animations.surfaceMorph + 120
        readonly property int completionTimeout: 3200
    }

    readonly property QtObject session: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int shellClearDelay: 520
    }

    readonly property QtObject settings: QtObject {
        readonly property int width: root.island.expandedWidth
        readonly property int height: 500
    }

    readonly property QtObject shortcuts: QtObject {
        readonly property bool managed: SettingsStore.boolValue(
            "shortcuts", "managed", false)
        readonly property bool launcher: SettingsStore.boolValue(
            "shortcuts", "launcher", true)
        readonly property bool commandLauncher: SettingsStore.boolValue(
            "shortcuts", "commandLauncher", true)
        readonly property bool clipboard: SettingsStore.boolValue(
            "shortcuts", "clipboard", true)
        readonly property bool settings: SettingsStore.boolValue(
            "shortcuts", "settings", true)
        readonly property bool notifications: SettingsStore.boolValue(
            "shortcuts", "notifications", true)
        readonly property bool wallpaper: SettingsStore.boolValue(
            "shortcuts", "wallpaper", true)
        readonly property bool controlCenter: SettingsStore.boolValue(
            "shortcuts", "controlCenter", true)
        readonly property bool lock: SettingsStore.boolValue(
            "shortcuts", "lock", true)
        readonly property bool regionScreenshot: SettingsStore.boolValue(
            "shortcuts", "regionScreenshot", true)
        readonly property bool regionRecording: SettingsStore.boolValue(
            "shortcuts", "regionRecording", true)
    }

    readonly property QtObject wallpaper: QtObject {
        readonly property string backend: "awww"
        readonly property string target: {
            const candidate = SettingsStore.value("wallpaper", "target", "current")
            return SettingsStore.validWallpaperTargets.indexOf(candidate) >= 0
                ? candidate : "current"
        }
        readonly property string scheme: {
            const candidate = SettingsStore.value("wallpaper", "scheme",
                "scheme-content")
            return SettingsStore.validSchemes.indexOf(candidate) >= 0
                ? candidate : "scheme-content"
        }
        readonly property var directories: [
            "wallpaper",
            "Pictures/Wallpapers",
            "Pictures/wallpapers"
        ]
        readonly property int width: root.island.expandedWidth
        readonly property int height: 440
        readonly property int galleryColumns: SettingsStore.numberValue(
            "wallpaper", "galleryColumns", 3, 2, 4)
        readonly property bool refreshOnOpen: SettingsStore.boolValue(
            "wallpaper", "refreshOnOpen", false)
        readonly property string transition: {
            const candidate = SettingsStore.value("wallpaper", "transition", "fade")
            return SettingsStore.validWallpaperTransitions.indexOf(candidate) >= 0
                ? candidate : "fade"
        }
        readonly property real transitionDuration: SettingsStore.numberValue(
            "wallpaper", "transitionDuration", 0.9, 0.3, 2.5)
        readonly property int cardHeight: 126
        readonly property string fitMode: "cover"
    }

    readonly property QtObject externalThemes: QtObject {
        // Hyprlock is the first approved active export; the remaining integrations
        // stay settings-owned and inactive until reversible controls exist.
        readonly property bool exportEnabled: true
        readonly property bool hyprlandEnabled: false
        readonly property bool hyprlockEnabled: SettingsStore.boolValue(
            "externalThemes", "hyprlock", false)
        readonly property bool gtkEnabled: false
        readonly property bool qtEnabled: false
        readonly property bool kittyEnabled: false
    }

    readonly property QtObject weather: QtObject {
        readonly property bool enabled: true
        readonly property string provider: "open-meteo"
        readonly property string locationName: {
            const candidate = SettingsStore.value("weather", "locationName", "")
            return typeof candidate === "string" ? candidate.trim() : ""
        }
        readonly property real latitude: coordinate("latitude", -90, 90)
        readonly property real longitude: coordinate("longitude", -180, 180)
        readonly property string temperatureUnit: "celsius"
        readonly property int refreshInterval: 1200000
        readonly property int requestTimeout: 8
        readonly property int headerSlotWidth: 56

        function coordinate(key: string, minimum: real, maximum: real): real {
            const stored = SettingsStore.value("weather", key, "")
            if ((typeof stored !== "number" && typeof stored !== "string")
                    || (typeof stored === "string" && stored.trim().length === 0))
                return NaN
            const numeric = Number(stored)
            return Number.isFinite(numeric) && numeric >= minimum
                && numeric <= maximum ? numeric : NaN
        }
    }

    readonly property QtObject ai: QtObject {
        readonly property bool enabled: false
        readonly property string provider: ""
        readonly property string model: ""
        readonly property string endpoint: ""
    }
}
