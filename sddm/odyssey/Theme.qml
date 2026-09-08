import QtQuick 2.15

QtObject {
    readonly property url background: config.background || "background.jpg"
    readonly property url currentWallpaper: config.currentWallpaper
        || "file:///var/tmp/odyssey-sddm-current-wallpaper"
    readonly property color surface: config.surface || "#101418"
    readonly property color surfaceHigh: config.surfaceHigh || "#272a2f"
    readonly property color text: config.text || "#e1e2e8"
    readonly property color textMuted: config.textMuted || "#c3c7cf"
    readonly property color outline: config.outline || "#42474e"
    readonly property color primary: config.primary || "#9fcafd"
    readonly property color error: config.error || "#ffb4ab"
    readonly property color warning: config.warning || "#f4c46b"
    readonly property color dimmer: config.dimmer || "#8c101418"
    readonly property int blurRadius: Number(config.blurRadius || 24)
    readonly property bool blurEnabled: String(config.blurEnabled).toLowerCase()
        !== "false"
    readonly property string fontFamily: config.fontFamily || "Adwaita Sans"
    readonly property string monoFontFamily: config.monoFontFamily
        || "JetBrainsMono Nerd Font"
}
