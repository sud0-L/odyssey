import QtQuick
import QtQuick.Shapes
import "../core"

Item {
    id: root

    property real radius: Theme.radiusLarge
    property color fillColor: Qt.alpha(Theme.surfaceContainer,
        Config.appearance.surfaceOpacity)
    property color outlineColor: Qt.alpha(Theme.outlineVariant,
        Theme.dark ? 0.62 : 0.48)
    property real outlineWidth: 1

    readonly property real shoulderWidth:
        Math.min(22, Math.max(12, width * 0.12))
    readonly property real edgeInset: Math.max(0.5, outlineWidth / 2)
    readonly property real cornerRadius: Math.max(0, Math.min(radius,
        (height - shoulderWidth * 2) / 2, width / 2))
    readonly property real curveFactor: 0.55228475
    readonly property color materialFillColor:
        SurfaceMaterial.fill(fillColor)
    readonly property color materialOutlineColor:
        SurfaceMaterial.outline(outlineColor)
    readonly property color gradientEdgeColor: SurfaceMaterial.glass
        ? Qt.tint(materialFillColor,
            Qt.alpha(SurfaceMaterial.compactHighlight, 0.10))
        : materialFillColor
    readonly property color gradientInnerColor: SurfaceMaterial.glass
        ? Qt.tint(materialFillColor,
            Qt.alpha(SurfaceMaterial.compactDepthEdge, 0.08))
        : materialFillColor

    Shape {
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
                y1: 0
                x2: root.width
                y2: 0
                GradientStop { position: 0; color: root.gradientInnerColor }
                GradientStop { position: 0.72; color: root.materialFillColor }
                GradientStop { position: 1; color: root.gradientEdgeColor }
            }
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            // The path deliberately extends its right-hand stroke beyond the
            // layer surface. The two cubic shoulders are the side-mounted
            // equivalent of IslandSurface's attached top-edge geometry.
            startX: root.width + root.edgeInset
            startY: -root.edgeInset
            PathLine {
                x: root.width + root.edgeInset
                y: root.height + root.edgeInset
            }
            PathCubic {
                x: root.width - root.shoulderWidth
                y: root.height - root.shoulderWidth
                control1X: root.width + root.edgeInset
                control1Y: root.height - root.shoulderWidth * 0.35
                control2X: root.width - root.shoulderWidth * 0.35
                control2Y: root.height - root.shoulderWidth
            }
            PathLine {
                x: root.edgeInset + root.cornerRadius
                y: root.height - root.shoulderWidth
            }
            PathCubic {
                x: root.edgeInset
                y: root.height - root.shoulderWidth - root.cornerRadius
                control1X: root.edgeInset + root.cornerRadius
                    - root.cornerRadius * root.curveFactor
                control1Y: root.height - root.shoulderWidth
                control2X: root.edgeInset
                control2Y: root.height - root.shoulderWidth
                    - root.cornerRadius + root.cornerRadius * root.curveFactor
            }
            PathLine {
                x: root.edgeInset
                y: root.shoulderWidth + root.cornerRadius
            }
            PathCubic {
                x: root.edgeInset + root.cornerRadius
                y: root.shoulderWidth
                control1X: root.edgeInset
                control1Y: root.shoulderWidth + root.cornerRadius
                    - root.cornerRadius * root.curveFactor
                control2X: root.edgeInset + root.cornerRadius
                    - root.cornerRadius * root.curveFactor
                control2Y: root.shoulderWidth
            }
            PathLine {
                x: root.width - root.shoulderWidth
                y: root.shoulderWidth
            }
            PathCubic {
                x: root.width + root.edgeInset
                y: -root.edgeInset
                control1X: root.width - root.shoulderWidth * 0.35
                control1Y: root.shoulderWidth
                control2X: root.width + root.edgeInset
                control2Y: root.shoulderWidth * 0.35
            }
        }
    }

    Behavior on fillColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on outlineColor {
        ColorAnimation { duration: Animations.normal }
    }
    Behavior on radius {
        NumberAnimation {
            duration: Animations.normal
            easing.type: Animations.standardEase
        }
    }
}
