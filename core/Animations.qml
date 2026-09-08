pragma Singleton
import QtQuick

QtObject {
    readonly property int fast: Config.animations.fast
    readonly property int normal: Config.animations.normal
    readonly property int large: Config.animations.large
    readonly property int emphasizedEase: Easing.OutCubic
    readonly property int standardEase: Easing.OutQuart
}
