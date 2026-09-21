import QtQuick
import QtQuick.Shapes
import "../core"

Item {
    id: root

    property real bodyWidth: 200
    property bool attached: false
    property real radius: Theme.radiusLarge
    property color fillColor: Qt.alpha(Theme.surfaceContainer,
        Config.appearance.surfaceOpacity)
    property color outlineColor: Qt.alpha(Theme.outlineVariant,
        Theme.dark ? 0.62 : 0.48)
    property real outlineWidth: 1
    // 0 uses the established panel material; 1 is tuned for the thin resting
    // Island. Intermediate values animate through hover/expansion morphs.
    property real compactGlass: 0
    property color materialFillColor: SurfaceMaterial.fill(fillColor,
        compactGlass)
    property color materialOutlineColor: SurfaceMaterial.outline(outlineColor)
    readonly property real shoulderWidth: attached
        ? Math.min(22, Math.max(12, height * 0.46)) : 0
    readonly property real edgeInset: Math.max(0.5, outlineWidth / 2)
    readonly property real cornerRadius: Math.max(0, Math.min(radius,
        (height - edgeInset * 2) / 2, bodyWidth / 2))
    readonly property real curveFactor: 0.55228475
    readonly property real topY: attached ? -edgeInset : edgeInset
    readonly property real bottomY: height - edgeInset
    readonly property real leftSide: attached ? shoulderWidth : edgeInset
    readonly property real rightSide: attached
        ? width - shoulderWidth : width - edgeInset
    readonly property real topShoulderY: attached
        ? shoulderWidth : edgeInset + cornerRadius
    readonly property real topStartX: attached
        ? edgeInset : edgeInset + cornerRadius
    readonly property real topEndX: attached
        ? width - edgeInset : width - edgeInset - cornerRadius
    readonly property color gradientTopColor: SurfaceMaterial.glass
        ? Qt.tint(materialFillColor, Qt.alpha(
            SurfaceMaterial.compactHighlight, compactGlass * 0.16))
        : materialFillColor
    readonly property color gradientBottomColor: SurfaceMaterial.glass
        ? Qt.tint(materialFillColor, Qt.alpha(
            SurfaceMaterial.compactDepthEdge, 0.08 + compactGlass * 0.05))
        : materialFillColor

    width: bodyWidth + shoulderWidth * 2
    clip: true

    Shape {
        id: surfaceShape
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.outlineWidth > 0
                ? root.materialOutlineColor : "transparent"
            strokeWidth: root.outlineWidth
            fillColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: root.topY
                x2: 0
                y2: root.bottomY
                GradientStop {
                    position: 0
                    color: root.gradientTopColor
                }
                GradientStop {
                    position: 0.42
                    color: root.materialFillColor
                }
                GradientStop {
                    position: 0.86
                    color: root.materialFillColor
                }
                GradientStop {
                    position: 1
                    color: root.gradientBottomColor
                }
            }
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: root.topStartX
            startY: root.topY

            PathLine {
                x: root.topEndX
                y: root.topY
            }
            PathCubic {
                x: root.rightSide
                y: root.topShoulderY
                control1X: root.attached
                    ? surfaceShape.width - root.shoulderWidth * 0.35
                    : root.topEndX + root.cornerRadius * root.curveFactor
                control1Y: root.topY
                control2X: root.rightSide
                control2Y: root.attached
                    ? root.shoulderWidth * 0.35
                    : root.topShoulderY
                        - root.cornerRadius * root.curveFactor
            }
            PathLine {
                x: root.rightSide
                y: root.bottomY - root.cornerRadius
            }
            PathCubic {
                x: root.rightSide - root.cornerRadius
                y: root.bottomY
                control1X: root.rightSide
                control1Y: root.bottomY - root.cornerRadius
                    + root.cornerRadius * root.curveFactor
                control2X: root.rightSide - root.cornerRadius
                    + root.cornerRadius * root.curveFactor
                control2Y: root.bottomY
            }
            PathLine {
                x: root.leftSide + root.cornerRadius
                y: root.bottomY
            }
            PathCubic {
                x: root.leftSide
                y: root.bottomY - root.cornerRadius
                control1X: root.leftSide + root.cornerRadius
                    - root.cornerRadius * root.curveFactor
                control1Y: root.bottomY
                control2X: root.leftSide
                control2Y: root.bottomY - root.cornerRadius
                    + root.cornerRadius * root.curveFactor
            }
            PathLine {
                x: root.leftSide
                y: root.topShoulderY
            }
            PathCubic {
                x: root.topStartX
                y: root.topY
                control1X: root.leftSide
                control1Y: root.attached
                    ? root.shoulderWidth * 0.35
                    : root.topShoulderY
                        - root.cornerRadius * root.curveFactor
                control2X: root.attached
                    ? root.shoulderWidth * 0.35
                    : root.topStartX - root.cornerRadius * root.curveFactor
                control2Y: root.topY
            }
        }
    }

    Behavior on fillColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on outlineColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on materialFillColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on materialOutlineColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on compactGlass {
        NumberAnimation {
            duration: Config.animations.surfaceMorph
            easing.type: Animations.emphasizedEase
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: Animations.normal
            easing.type: Animations.standardEase
        }
    }
}
