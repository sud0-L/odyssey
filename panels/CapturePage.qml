import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property var monitor
    property string screenshotOutputMode: CaptureService.clipboardAvailable
        ? "both" : "save"
    property string recordingTarget: "monitor"
    property bool includeSystemAudio: true
    readonly property string monitorName: monitor?.name || ""

    TextMetrics {
        id: screenshotTitleMetrics
        font.family: Config.appearance.fontFamily
        font.pixelSize: Theme.textBody
        text: "M"
    }

    TextMetrics {
        id: screenshotSubtitleMetrics
        font.family: Config.appearance.fontFamily
        font.pixelSize: Theme.textSmall
        text: "M"
    }

    TextMetrics {
        id: recordingTitleMetrics
        font.family: Config.appearance.fontFamily
        font.pixelSize: Theme.textBody
        text: "M"
    }

    TextMetrics {
        id: recordingSubtitleMetrics
        font.family: Config.appearance.monoFontFamily
        font.pixelSize: Theme.textSmall
        text: "M"
    }

    TextMetrics {
        id: outputLabelMetrics
        font.family: Config.appearance.monoFontFamily
        font.pixelSize: 9
        text: "M"
    }

    signal dismissRequested(bool forceDormant)

    function requestScreenshot(mode: string): void {
        if (CaptureService.scheduleScreenshot(mode, monitorName,
                screenshotOutputMode))
            dismissRequested(true)
    }

    function requestRecording(): void {
        const scheduled = CaptureService.scheduleRecording(recordingTarget,
            monitorName, includeSystemAudio)
        // Region selection needs the shell to release its focus grab before
        // slurp starts. Monitor recording remains visible as a background mode.
        if (scheduled && recordingTarget === "region")
            dismissRequested(true)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: Theme.space2

            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                spacing: 0

                Text {
                    text: "Capture"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Screenshots and screen recording"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: CaptureService.recording
                Layout.alignment: Qt.AlignBottom
                Layout.preferredWidth: recordingHeaderText.implicitWidth
                    + Theme.space4 * 2
                Layout.preferredHeight: 30
                radius: 15
                color: Qt.alpha(Theme.error, 0.14)

                Text {
                    id: recordingHeaderText
                    anchors.centerIn: parent
                    text: "Recording  " + CaptureService.elapsedLabel
                    color: Theme.error
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space3

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Qt.alpha(Theme.surfaceContainer, 0.74)
                border.width: 1
                border.color: Qt.alpha(Theme.outlineVariant, 0.42)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space4
                    spacing: Theme.space3

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: screenshotTitleMetrics.height
                            + screenshotSubtitleMetrics.height
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "󰄀"
                            color: Theme.primary
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: Theme.iconMedium
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "Screenshot"
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textBody
                            font.weight: Font.DemiBold
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: Theme.space2
                        columnSpacing: Theme.space2

                        Repeater {
                            model: [
                                { mode: "full", icon: "󰍹", title: "All displays",
                                    detail: "The complete desktop" },
                                { mode: "monitor", icon: "󰍺", title: "This display",
                                    detail: root.monitorName || "Focused display" },
                                { mode: "region", icon: "󰒉", title: "Select region",
                                    detail: "Draw an area to capture" },
                                { mode: "active", icon: "󰖯", title: "Active window",
                                    detail: "The currently focused window" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusMedium
                                color: shotHover.hovered
                                    ? Theme.surfaceContainerHigh
                                    : Qt.alpha(Theme.surfaceContainerHigh, 0.50)
                                border.width: 1
                                border.color: shotHover.hovered
                                    ? Qt.alpha(Theme.primary, 0.56)
                                    : Qt.alpha(Theme.outlineVariant, 0.34)
                                opacity: CaptureService.screenshotAvailable
                                    && !CaptureService.busy ? 1 : 0.44

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space3
                                    spacing: Theme.space2
                                    Text {
                                        text: modelData.icon
                                        color: Theme.primary
                                        font.family: Config.appearance.monoFontFamily
                                        font.pixelSize: Theme.iconMedium
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            text: modelData.title
                                            color: Theme.surfaceText
                                            font.family: Config.appearance.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.detail
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            font.family: Config.appearance.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                HoverHandler { id: shotHover }
                                TapHandler {
                                    enabled: CaptureService.screenshotAvailable
                                        && !CaptureService.busy
                                    onTapped: root.requestScreenshot(modelData.mode)
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Animations.fast }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: outputLabelMetrics.height
                            + Theme.space1 + outputModeRow.implicitHeight
                        spacing: Theme.space1
                        RowLayout {
                            id: outputModeRow
                            Layout.fillWidth: true
                            spacing: Theme.space1
                            Repeater {
                                model: [
                                    { value: "both", label: "Save + copy" },
                                    { value: "save", label: "Save file" },
                                    { value: "copy", label: "Clipboard" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 15
                                    color: root.screenshotOutputMode === modelData.value
                                        ? Theme.primaryContainer
                                        : outputHover.hovered
                                            ? Theme.surfaceContainerHigh : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: root.screenshotOutputMode === modelData.value
                                            ? Theme.primaryContainerText
                                            : Theme.surfaceVariantText
                                        font.family: Config.appearance.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                    HoverHandler { id: outputHover }
                                    TapHandler {
                                        enabled: modelData.value === "save"
                                            || CaptureService.clipboardAvailable
                                        onTapped: root.screenshotOutputMode = modelData.value
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 228
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Qt.alpha(Theme.surfaceContainer, 0.74)
                border.width: 1
                border.color: CaptureService.recording
                    ? Qt.alpha(Theme.error, 0.58)
                    : Qt.alpha(Theme.outlineVariant, 0.42)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space4
                    spacing: Theme.space3

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: recordingTitleMetrics.height
                            + recordingSubtitleMetrics.height
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "󰑊"
                            color: CaptureService.recording ? Theme.error : Theme.tertiary
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: Theme.iconMedium
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "Screen recording"
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.textBody
                            font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space1
                        Text {
                            text: "CAPTURE"
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                        }
                        Repeater {
                            model: [
                                { value: "monitor", icon: "󰍺", label: "This display" },
                                { value: "region", icon: "󰒉", label: "Selected region" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: Theme.radiusMedium
                                color: root.recordingTarget === modelData.value
                                    ? Qt.alpha(Theme.tertiary, 0.18)
                                    : targetHover.hovered
                                        ? Theme.surfaceContainerHigh : "transparent"
                                border.width: 1
                                border.color: root.recordingTarget === modelData.value
                                    ? Qt.alpha(Theme.tertiary, 0.50)
                                    : Qt.alpha(Theme.outlineVariant, 0.28)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space2
                                    Text {
                                        text: modelData.icon
                                        color: Theme.tertiary
                                        font.family: Config.appearance.monoFontFamily
                                        font.pixelSize: Theme.iconSmall
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: Theme.surfaceText
                                        font.family: Config.appearance.fontFamily
                                        font.pixelSize: 11
                                    }
                                    Text {
                                        visible: root.recordingTarget === modelData.value
                                        text: "󰄬"
                                        color: Theme.tertiary
                                        font.family: Config.appearance.monoFontFamily
                                    }
                                }
                                HoverHandler { id: targetHover }
                                TapHandler {
                                    enabled: !CaptureService.recording
                                    onTapped: root.recordingTarget = modelData.value
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: Theme.radiusMedium
                        color: audioHover.hovered
                            ? Theme.surfaceContainerHigh : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.space2
                            Text {
                                text: root.includeSystemAudio ? "󰕾" : "󰝟"
                                color: root.includeSystemAudio
                                    ? Theme.primary : Theme.surfaceVariantText
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: Theme.iconSmall
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "System audio"
                                color: Theme.surfaceText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Normal
                            }
                            Text {
                                text: root.includeSystemAudio ? "ON" : "OFF"
                                color: root.includeSystemAudio
                                    ? Theme.primary : Theme.surfaceVariantText
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: 11
                                font.weight: Font.Normal
                            }
                        }
                        HoverHandler { id: audioHover }
                        TapHandler {
                            enabled: !CaptureService.recording
                            onTapped: root.includeSystemAudio = !root.includeSystemAudio
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 24
                        color: CaptureService.recording
                            ? Qt.alpha(Theme.error, recordHover.hovered ? 0.34 : 0.26)
                            : recordHover.hovered
                                ? Theme.tertiary : Qt.alpha(Theme.tertiary, 0.82)
                        border.width: CaptureService.recording ? 1 : 0
                        border.color: Qt.alpha(Theme.error, 0.72)
                        opacity: CaptureService.recordingAvailable
                            && !CaptureService.busy ? 1 : 0.42
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.space2
                            RecordingDot {
                                active: CaptureService.recording
                                dotSize: CaptureService.recording ? 14 : 10
                                color: CaptureService.recording
                                    ? Theme.error : Theme.primaryText
                            }
                            Text {
                                text: CaptureService.recording
                                    ? "Stop recording"
                                    : CaptureService.preparingRecording
                                        ? "Starting…" : "Start recording"
                                color: CaptureService.recording
                                    ? Theme.error : Theme.primaryText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                        HoverHandler { id: recordHover }
                        TapHandler {
                            enabled: CaptureService.recordingAvailable
                                && !CaptureService.busy
                            onTapped: CaptureService.recording
                                ? CaptureService.stopRecording()
                                : root.requestRecording()
                        }
                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }
                    }
                }
            }
        }
    }
}
