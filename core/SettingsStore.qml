pragma Singleton
import QtCore
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var values: ({})
    property bool loaded: false
    property string errorMessage: ""

    readonly property var validModes: ["auto", "dark", "light"]
    readonly property var validSchemes: [
        "scheme-content", "scheme-tonal-spot", "scheme-vibrant",
        "scheme-monochrome", "scheme-expressive", "scheme-fidelity",
        "scheme-fruit-salad", "scheme-neutral", "scheme-rainbow"
    ]
    readonly property var validMotionSpeeds: ["quick", "balanced", "calm"]
    readonly property var validDensities: ["compact", "balanced", "airy"]
    readonly property var validCornerStyles: ["subtle", "balanced", "round"]
    readonly property var validMediaHoverModes: ["hidden", "playing", "available"]
    readonly property var validWallpaperTargets: ["current", "all"]
    readonly property var validWallpaperTransitions: [
        "fade", "slide", "wipe", "wave", "expand", "contract",
        "spotlight", "random"
    ]
    readonly property var validIslandPolicies: ["all", "primary"]
    readonly property var validRestIslandItems: [
        "Weather", "Dnd", "KeepAwake", "PowerProfile"
    ]
    readonly property var validHoverIslandItems: [
        "Workspaces", "Clock", "Media", "Audio", "Network", "Dnd",
        "Bluetooth", "KeepAwake", "Battery"
    ]

    function value(section: string, key: string, fallback): var {
        const group = values?.[section]
        return group && group[key] !== undefined ? group[key] : fallback
    }

    function boolValue(section: string, key: string, fallback: bool): bool {
        const stored = value(section, key, fallback)
        return typeof stored === "boolean" ? stored : fallback
    }

    function numberValue(section: string, key: string, fallback: real,
            minimum: real, maximum: real): real {
        const stored = Number(value(section, key, fallback))
        return Number.isFinite(stored)
            ? Math.max(minimum, Math.min(maximum, stored)) : fallback
    }

    function stringListValue(section: string, key: string, fallback,
            allowedValues): var {
        const stored = value(section, key, fallback)
        if (!Array.isArray(stored))
            return fallback.slice()
        const result = []
        for (const candidate of stored) {
            if (typeof candidate === "string"
                    && allowedValues.indexOf(candidate) >= 0
                    && result.indexOf(candidate) < 0)
                result.push(candidate)
        }
        return result
    }

    function setValue(section: string, key: string, nextValue): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (!updated[section] || typeof updated[section] !== "object")
            updated[section] = {}
        updated[section][key] = nextValue
        values = updated
        save()
    }

    function removeValue(section: string, key: string): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (!updated[section] || updated[section][key] === undefined)
            return
        delete updated[section][key]
        if (Object.keys(updated[section]).length === 0)
            delete updated[section]
        values = updated
        save()
    }

    function setValidatedValue(section: string, key: string, nextValue,
            allowedValues): bool {
        if (allowedValues.indexOf(nextValue) < 0)
            return false
        setValue(section, key, nextValue)
        return true
    }

    function setAppearanceMode(mode: string): bool {
        if (validModes.indexOf(mode) < 0)
            return false
        setValue("appearance", "mode", mode)
        return true
    }

    function setSurfaceOpacity(opacity: real): void {
        setValue("appearance", "surfaceOpacity",
            Math.round(Math.max(0.72, Math.min(1, opacity)) * 100) / 100)
    }

    function setAccentOverride(color: string): bool {
        if (typeof color !== "string"
                || !/^#[0-9a-fA-F]{6}$/.test(color))
            return false
        setValue("appearance", "accentOverride", color.toLowerCase())
        return true
    }

    function clearAccentOverride(): void {
        removeValue("appearance", "accentOverride")
    }

    function setReducedMotion(enabled: bool): void {
        setValue("appearance", "reducedMotion", enabled)
    }

    function setMotionSpeed(speed: string): bool {
        return setValidatedValue("appearance", "motionSpeed", speed,
            validMotionSpeeds)
    }

    function setDensity(density: string): bool {
        return setValidatedValue("appearance", "density", density,
            validDensities)
    }

    function setCornerStyle(style: string): bool {
        return setValidatedValue("appearance", "cornerStyle", style,
            validCornerStyles)
    }

    function setClock24Hour(enabled: bool): void {
        setValue("appearance", "use24HourClock", enabled)
    }

    function setIslandMetric(metric: string, nextValue: real): bool {
        const bounds = ({
            topMargin: [0, 16], reservedSpace: [26, 52],
            dormantWidth: [214, 320], hoverWidth: [470, 760],
            expandedWidth: [620, 900], restItemSpacing: [2, 18],
            hoverItemSpacing: [2, 20], autoHideDelay: [500, 10000]
        })
        const range = bounds[metric]
        const numeric = Number(nextValue)
        if (!range || !Number.isFinite(numeric))
            return false
        setValue("island", metric,
            Math.round(Math.max(range[0], Math.min(range[1], numeric))))
        return true
    }

    function setIslandItemVisible(context: string, item: string,
            enabled: bool): bool {
        const allowed = context === "rest" ? validRestIslandItems
            : context === "hover" ? validHoverIslandItems : []
        if (allowed.indexOf(item) < 0)
            return false
        const fallback = context === "rest" ? validRestIslandItems
            : validHoverIslandItems
        const current = stringListValue("island", context + "ItemOrder",
            fallback, allowed)
        const next = current.filter(candidate => candidate !== item)
        if (enabled)
            next.push(item)
        return setIslandItemOrder(context, next)
    }

    function setIslandItemOrder(context: string, order): bool {
        const allowed = context === "rest" ? validRestIslandItems
            : context === "hover" ? validHoverIslandItems : []
        if (!Array.isArray(order) || allowed.length === 0)
            return false
        const validated = []
        for (const candidate of order) {
            if (typeof candidate !== "string"
                    || allowed.indexOf(candidate) < 0
                    || validated.indexOf(candidate) >= 0)
                return false
            validated.push(candidate)
        }
        setValue("island", context + "ItemOrder", validated)
        return true
    }

    function setIslandAutoHide(enabled: bool): void {
        setValue("island", "autoHide", enabled)
    }

    function setIslandRevealLip(enabled: bool): void {
        setValue("island", "showRevealLip", enabled)
    }

    function setIslandContentSync(context: string, enabled: bool): bool {
        if (["rest", "hover"].indexOf(context) < 0)
            return false
        const textKey = context + "TextScale"
        const iconKey = context + "IconScale"
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (!updated.island || typeof updated.island !== "object")
            updated.island = {}
        updated.island[context + "ScaleSynced"] = enabled
        if (enabled) {
            const shared = numberValue("island", textKey, 100, 80, 130)
            updated.island[textKey] = shared
            updated.island[iconKey] = shared
        }
        values = updated
        save()
        return true
    }

    function setIslandContentScale(context: string, channel: string,
            percentage: real): bool {
        if (["rest", "hover"].indexOf(context) < 0
                || ["text", "icon"].indexOf(channel) < 0)
            return false
        const numeric = Number(percentage)
        if (!Number.isFinite(numeric))
            return false
        const bounded = Math.round(Math.max(80, Math.min(130, numeric)))
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (!updated.island || typeof updated.island !== "object")
            updated.island = {}
        updated.island[context + (channel === "text"
            ? "TextScale" : "IconScale")] = bounded
        if (boolValue("island", context + "ScaleSynced", true))
            updated.island[context + (channel === "text"
                ? "IconScale" : "TextScale")] = bounded
        values = updated
        save()
        return true
    }

    function resetIslandAndMotion(): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        delete updated.island
        if (updated.appearance) {
            delete updated.appearance.motionSpeed
            delete updated.appearance.density
            delete updated.appearance.cornerStyle
            delete updated.appearance.reducedMotion
            if (Object.keys(updated.appearance).length === 0)
                delete updated.appearance
        }
        values = updated
        save()
    }

    function setIdleManaged(enabled: bool): void {
        setValue("idle", "managed", enabled)
    }

    function setIdleMetric(metric: string, nextValue: real): bool {
        const bounds = ({
            dimMinutes: [1, 999], lockMinutes: [1, 999],
            displayOffMinutes: [1, 999], suspendMinutes: [1, 999],
            hibernateMinutes: [1, 999], dimPercent: [5, 90]
        })
        const range = bounds[metric]
        const numeric = Number(nextValue)
        if (!range || !Number.isFinite(numeric))
            return false
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (!updated.idle || typeof updated.idle !== "object")
            updated.idle = {}
        updated.idle[metric] = Math.round(Math.max(range[0],
            Math.min(range[1], numeric)))
        const keys = ["dimMinutes", "lockMinutes", "displayOffMinutes",
            "suspendMinutes", "hibernateMinutes"]
        const defaults = [5, 10, 12, 30, 90]
        const selected = keys.indexOf(metric)
        if (selected >= 0) {
            const stages = keys.map((key, index) =>
                Number(updated.idle[key] ?? defaults[index]))
            for (let index = selected - 1; index >= 0; --index)
                stages[index] = Math.min(stages[index], stages[index + 1])
            for (let index = selected + 1; index < stages.length; ++index)
                stages[index] = Math.max(stages[index], stages[index - 1])
            keys.forEach((key, index) => updated.idle[key] = stages[index])
        }
        values = updated
        save()
        return true
    }

    function setPowerSoundsEnabled(enabled: bool): void {
        setValue("idle", "powerSoundsEnabled", enabled)
    }

    function resetIdlePolicy(): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        delete updated.idle
        values = updated
        save()
    }

    function setIslandMonitorPolicy(policy: string): bool {
        return setValidatedValue("displays", "islandPolicy", policy,
            validIslandPolicies)
    }

    function setPrimaryMonitor(monitorName: string): bool {
        if (typeof monitorName !== "string"
                || !/^(auto|[A-Za-z0-9._:-]+)$/.test(monitorName))
            return false
        setValue("displays", "primaryMonitor", monitorName)
        return true
    }

    function resetDisplays(): void {
        resetSection("displays")
    }

    function setNotificationToggle(key: string, enabled: bool): bool {
        if (["showPopups", "allowCriticalAlerts", "doNotDisturb"]
                .indexOf(key) < 0)
            return false
        setValue("notifications", key, enabled)
        return true
    }

    function setNotificationDuration(key: string, milliseconds: real): bool {
        const bounds = ({ timeout: [2000, 10000], criticalTimeout: [4000, 15000] })
        const range = bounds[key]
        const numeric = Number(milliseconds)
        if (!range || !Number.isFinite(numeric))
            return false
        setValue("notifications", key, Math.round(Math.max(range[0],
            Math.min(range[1], numeric)) / 1000) * 1000)
        return true
    }

    function setNotificationHistoryLimit(limit: real): bool {
        const numeric = Number(limit)
        if (!Number.isFinite(numeric))
            return false
        setValue("notifications", "historyLimit",
            Math.round(Math.max(20, Math.min(100, numeric))))
        return true
    }

    function resetNotifications(): void {
        resetSection("notifications")
    }

    function setMediaToggle(key: string, enabled: bool): bool {
        if (["enabled", "preferPlaying"].indexOf(key) < 0)
            return false
        setValue("media", key, enabled)
        return true
    }

    function setMediaPresentationTimeout(milliseconds: real): bool {
        const numeric = Number(milliseconds)
        if (!Number.isFinite(numeric))
            return false
        setValue("media", "presentationTimeout", Math.round(Math.max(2000,
            Math.min(10000, numeric)) / 1000) * 1000)
        return true
    }

    function setMediaHoverMode(mode: string): bool {
        return setValidatedValue("media", "hoverMode", mode,
            validMediaHoverModes)
    }

    function resetMedia(): void {
        resetSection("media")
    }

    function setWallpaperTarget(target: string): bool {
        return setValidatedValue("wallpaper", "target", target,
            validWallpaperTargets)
    }

    function setWallpaperGalleryColumns(columns: real): bool {
        const numeric = Number(columns)
        if (!Number.isFinite(numeric))
            return false
        setValue("wallpaper", "galleryColumns",
            Math.round(Math.max(2, Math.min(4, numeric))))
        return true
    }

    function setWallpaperRefreshOnOpen(enabled: bool): void {
        setValue("wallpaper", "refreshOnOpen", enabled)
    }

    function setWallpaperTransition(transition: string): bool {
        return setValidatedValue("wallpaper", "transition", transition,
            validWallpaperTransitions)
    }

    function setWallpaperTransitionDuration(duration: real): bool {
        const numeric = Number(duration)
        if (!Number.isFinite(numeric))
            return false
        // Store a stable tenth-second value so awww never sees unbounded UI noise.
        setValue("wallpaper", "transitionDuration", Math.round(
            Math.max(0.3, Math.min(2.5, numeric)) * 10) / 10)
        return true
    }

    function resetWallpaper(): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        const scheme = updated.wallpaper?.scheme
        if (scheme === undefined)
            delete updated.wallpaper
        else
            updated.wallpaper = ({ scheme: scheme })
        values = updated
        save()
    }

    function setDashboardSection(section: string, enabled: bool): bool {
        if (["showHero", "showMedia", "showSystem", "showQuickStrip"]
                .indexOf(section) < 0)
            return false
        if (!enabled && ((section === "showMedia"
                && !boolValue("dashboard", "showSystem", true))
                || (section === "showSystem"
                    && !boolValue("dashboard", "showMedia", true))))
            return false
        setValue("dashboard", section, enabled)
        return true
    }

    function resetDashboard(): void {
        resetSection("dashboard")
    }

    function setWeatherLocation(locationName: string, latitude,
            longitude): bool {
        const name = typeof locationName === "string"
            ? locationName.trim() : ""
        const latitudeNumber = Number(latitude)
        const longitudeNumber = Number(longitude)
        if (name.length === 0 || name.length > 100
                || !Number.isFinite(latitudeNumber)
                || latitudeNumber < -90 || latitudeNumber > 90
                || !Number.isFinite(longitudeNumber)
                || longitudeNumber < -180 || longitudeNumber > 180)
            return false
        const updated = JSON.parse(JSON.stringify(values || {}))
        updated.weather = ({
            locationName: name,
            latitude: latitudeNumber,
            longitude: longitudeNumber
        })
        values = updated
        save()
        return true
    }

    function clearWeatherLocation(): void {
        resetSection("weather")
    }

    function setShortcutsManaged(enabled: bool): void {
        setValue("shortcuts", "managed", enabled)
    }

    function setShortcutEnabled(action: string, enabled: bool): bool {
        if (["launcher", "clipboard", "settings", "notifications",
                "wallpaper", "controlCenter", "lock", "regionScreenshot",
                "regionRecording"].indexOf(action) < 0)
            return false
        setValue("shortcuts", action, enabled)
        return true
    }

    function resetShortcuts(): void {
        resetSection("shortcuts")
    }

    function resetSection(section: string): void {
        const updated = JSON.parse(JSON.stringify(values || {}))
        if (updated[section] === undefined)
            return
        delete updated[section]
        values = updated
        save()
    }

    function setWallpaperPaletteEnabled(enabled: bool): void {
        setValue("appearance", "wallpaperPaletteEnabled", enabled)
    }

    function setScheme(scheme: string): bool {
        if (validSchemes.indexOf(scheme) < 0)
            return false
        setValue("wallpaper", "scheme", scheme)
        return true
    }

    function setExternalTheme(target: string, enabled: bool): bool {
        if (["hyprland", "hyprlock", "gtk", "qt", "kitty"]
                .indexOf(target) < 0)
            return false
        setValue("externalThemes", target, enabled)
        return true
    }

    function save(): void {
        if (!loaded)
            return
        settingsFile.setText(JSON.stringify({
            version: 1,
            settings: values
        }, null, 2))
    }

    function load(raw: string): void {
        try {
            const parsed = JSON.parse(raw)
            values = parsed?.settings && typeof parsed.settings === "object"
                ? parsed.settings : ({})
            errorMessage = ""
        } catch (error) {
            values = ({})
            errorMessage = "Settings could not be read"
            console.warn("Odyssey SettingsStore:", error)
        }
        loaded = true
    }

    property FileView settingsFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
            + "/odyssey/settings.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: root.load(text())
        onFileChanged: reload()
        onLoadFailed: error => {
            root.loaded = true
            if (error !== FileViewError.FileNotFound) {
                root.errorMessage = "Settings could not be loaded"
                console.warn("Odyssey SettingsStore:",
                    FileViewError.toString(error))
            }
        }
        onSaveFailed: error => {
            root.errorMessage = "Settings could not be saved"
            console.warn("Odyssey SettingsStore:",
                FileViewError.toString(error))
        }
    }
}
