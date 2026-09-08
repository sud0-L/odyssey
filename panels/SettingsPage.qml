import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property var monitor
    property string section: "appearance"
    property string pillPreviewMode: "rest"
    property string islandEditor: "overview"
    property bool accentPaletteOpen: false
    property string stagedAccent: Config.appearance.accentOverride
    property string pickedAccent: ""
    property string weatherNameDraft: Config.weather.locationName
    property string weatherLatitudeDraft: Number.isFinite(Config.weather.latitude)
        ? Config.weather.latitude.toString() : ""
    property string weatherLongitudeDraft: Number.isFinite(Config.weather.longitude)
        ? Config.weather.longitude.toString() : ""
    readonly property bool weatherDraftValid: weatherNameDraft.trim().length > 0
        && weatherNameDraft.trim().length <= 100
        && weatherLatitudeDraft.trim().length > 0
        && weatherLongitudeDraft.trim().length > 0
        && Number.isFinite(Number(weatherLatitudeDraft))
        && Number(weatherLatitudeDraft) >= -90
        && Number(weatherLatitudeDraft) <= 90
        && Number.isFinite(Number(weatherLongitudeDraft))
        && Number(weatherLongitudeDraft) >= -180
        && Number(weatherLongitudeDraft) <= 180
    readonly property bool livePreviewActive: section === "island"
        && islandEditor !== "overview"
    function setIslandItem(context: string, item: string,
            enabled: bool): void {
        pillPreviewMode = context
        SettingsStore.setIslandItemVisible(context, item, enabled)
    }
    function setIslandSpacing(context: string, value: real): void {
        pillPreviewMode = context
        SettingsStore.setIslandMetric(context + "ItemSpacing", value)
    }
    function pickAccentFromScreen(): void {
        if (!accentPicker.running) {
            pickedAccent = ""
            accentPicker.command = ["hyprpicker", "--format", "hex", "--no-fancy",
                "--lowercase-hex"]
            accentPicker.running = true
        }
    }
    property Process accentPicker: Process {
        stdout: StdioCollector { onStreamFinished: root.pickedAccent = text.trim() }
        onExited: code => {
            if (code === 0 && /^#[0-9a-fA-F]{6}$/.test(root.pickedAccent))
                AppearanceService.setAccentOverride(root.pickedAccent.toLowerCase())
        }
    }
    onSectionChanged: {
        if (section !== "island")
            islandEditor = "overview"
        Qt.callLater(() => settingsScroll.contentY = 0)
    }
    onIslandEditorChanged: Qt.callLater(() => settingsScroll.contentY = 0)
    readonly property var sections: [
        { id: "appearance", icon: "󰏘", label: "Appearance" },
        { id: "island", icon: "󰇄", label: "Island & Motion" },
        { id: "idle", icon: "󰅶", label: "Power & Idle" },
        { id: "displays", icon: "󰍹", label: "Displays" },
        { id: "notifications", icon: "󰂚", label: "Notifications" },
        { id: "media", icon: "󰝚", label: "Media" },
        { id: "wallpaper", icon: "󰸉", label: "Wallpaper" },
        { id: "dashboard", icon: "󰕮", label: "Dashboard" },
        { id: "shortcuts", icon: "󰌌", label: "Shortcuts" },
        { id: "integrations", icon: "󰕮", label: "System Integrations" }
    ]
    readonly property var currentSection: sections.find(
        option => option.id === section) || sections[0]

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Rectangle {
            Layout.preferredWidth: 154
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.surfaceContainerLow, 0.44)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.28)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space1

                Text {
                    Layout.leftMargin: Theme.space1
                    Layout.bottomMargin: Theme.space1
                    text: "ODYSSEY  /  SETTINGS"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Repeater {
                    model: root.sections
                    delegate: Rectangle {
                        id: sectionButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 31
                        activeFocusOnTab: true
                        radius: Theme.radiusSmall
                        color: root.section === modelData.id
                            ? Qt.alpha(Theme.primaryContainer, 0.82)
                            : sectionHover.hovered
                                ? Qt.alpha(Theme.surfaceContainerHigh, 0.72)
                                : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Qt.alpha(Theme.primary, 0.78)

                        Keys.onReturnPressed: root.section = modelData.id
                        Keys.onEnterPressed: root.section = modelData.id
                        Keys.onSpacePressed: root.section = modelData.id

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space2
                            anchors.rightMargin: Theme.space2
                            spacing: Theme.space1
                            Rectangle {
                                Layout.preferredWidth: 3
                                Layout.preferredHeight: 15
                                radius: 2
                                visible: root.section === modelData.id
                                color: Theme.primary
                            }
                            Text {
                                text: modelData.icon
                                color: root.section === modelData.id
                                    ? Theme.primary
                                    : Theme.surfaceVariantText
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: Theme.iconSmall
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: root.section === modelData.id
                                    ? Theme.surfaceText : Theme.surfaceVariantText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                        HoverHandler { id: sectionHover }
                        TapHandler {
                            onTapped: {
                                sectionButton.forceActiveFocus()
                                root.section = modelData.id
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    visible: SettingsStore.errorMessage.length > 0
                    Layout.fillWidth: true
                    text: SettingsStore.errorMessage
                    color: Theme.error
                    wrapMode: Text.WordWrap
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.space2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: Theme.space2
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusSmall
                        color: Qt.alpha(Theme.primaryContainer, 0.78)
                        Text {
                            anchors.centerIn: parent
                            text: root.currentSection.icon
                            color: Theme.primary
                            font.family: Config.appearance.monoFontFamily
                            font.pixelSize: Theme.iconSmall
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: root.section === "island"
                                    && root.islandEditor === "geometry"
                                ? "Live Edit"
                                : root.section === "island"
                                    && root.islandEditor === "content"
                                    ? "Resting & Hover Island"
                                    : root.currentSection.label
                            color: Theme.surfaceText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.section === "appearance"
                                ? "Color, surfaces, and motion"
                                : root.section === "island"
                                    ? "Footprint, rhythm, and resting content"
                                : root.section === "idle"
                                    ? "Screen rest and system sleep"
                                : root.section === "displays"
                                    ? "Placement and display policy"
                                : root.section === "notifications"
                                    ? "Interruption and local history"
                                : root.section === "media"
                                    ? "Playback presence in the Island"
                                : root.section === "wallpaper"
                                    ? "Library, color, and transitions"
                                : root.section === "dashboard"
                                    ? "Overview appearance"
                                : root.section === "shortcuts"
                                    ? "Keybinds managed by Odyssey"
                                    : "Explicit external theme ownership"
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Flickable {
                    id: settingsScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: pageContent.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: pageContent
                        width: parent.width
                        spacing: Theme.space2

                        ColumnLayout {
                            visible: root.section === "appearance"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Theme mode"
                                detail: "Auto follows the generated wallpaper palette"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "auto", label: "Auto" },
                                            { id: "dark", label: "Dark" },
                                            { id: "light", label: "Light" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.appearance.mode === modelData.id
                                            onActivated: AppearanceService.setMode(modelData.id)
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Surface opacity"
                                detail: Math.round(Config.appearance.surfaceOpacity * 100)
                                    + "% · Applies live to expanded Odyssey surfaces"
                                inlineLayout: true
                                contentHeight: 36
                                SettingsSlider {
                                    width: 190
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0.72
                                    to: 1
                                    stepSize: 0.01
                                    value: Config.appearance.surfaceOpacity
                                    onAdjusted: value => AppearanceService
                                        .setSurfaceOpacity(value)
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Color style"
                                detail: AppearanceService.changingScheme
                                    ? "Generating a new palette…"
                                    : "Choose how Matugen interprets the current wallpaper"
                                contentHeight: 100
                                GridLayout {
                                    anchors.fill: parent
                                    columns: 3
                                    columnSpacing: Theme.space2
                                    rowSpacing: Theme.space2
                                    Repeater {
                                        model: [
                                            { id: "scheme-content", label: "Content" },
                                            { id: "scheme-tonal-spot", label: "Tonal" },
                                            { id: "scheme-vibrant", label: "Vibrant" },
                                            { id: "scheme-monochrome", label: "Monochrome" },
                                            { id: "scheme-expressive", label: "Expressive" },
                                            { id: "scheme-fidelity", label: "Fidelity" },
                                            { id: "scheme-fruit-salad", label: "Fruit salad" },
                                            { id: "scheme-neutral", label: "Neutral" },
                                            { id: "scheme-rainbow", label: "Rainbow" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            compact: true
                                            label: modelData.label
                                            selected: Config.wallpaper.scheme === modelData.id
                                            available: !AppearanceService.changingScheme
                                            onActivated: AppearanceService.setScheme(modelData.id)
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Accent color override"
                                detail: accentPaletteOpen ? "Pick a color, then Use color to commit it" : "Optional primary-accent override"
                                contentHeight: accentPaletteOpen ? 222 : 34
                                ColumnLayout { anchors.fill: parent; spacing: Theme.space2
                                    RowLayout { Layout.fillWidth: true; spacing: Theme.space2
                                        AccentSwatch { swatchColor: Theme.primary; glyph: "󰏘"; selected: !Theme.accentOverridden; onActivated: AppearanceService.clearAccentOverride() }
                                        Repeater { model: ["#7c3aed", "#0284c7", "#059669", "#d97706", "#e11d48"]; delegate: AccentSwatch { required property string modelData; swatchColor: modelData; selected: Config.appearance.accentOverride === modelData; onActivated: AppearanceService.setAccentOverride(modelData) } }
                                        AccentSwatch { swatchColor: Theme.primary; glyph: "󰐕"; selected: accentPaletteOpen; onActivated: { root.stagedAccent = Config.appearance.accentOverride; root.accentPaletteOpen = !root.accentPaletteOpen } }
                                        Item { Layout.fillWidth: true }
                                    }
                                    GridLayout { visible: root.accentPaletteOpen; Layout.alignment: Qt.AlignHCenter; columns: 9; columnSpacing: 4; rowSpacing: 4
                                        Repeater { model: ["#1d4ed8","#2563eb","#3b82f6","#60a5fa","#93c5fd", "#047857","#059669","#10b981","#34d399","#6ee7b7", "#ca8a04","#eab308","#facc15","#fde047","#fef08a", "#c2410c","#ea580c","#f97316","#fb923c","#fdba74", "#be123c","#e11d48","#f43f5e","#fb7185","#fda4af", "#6d28d9","#7c3aed","#8b5cf6","#a78bfa","#c4b5fd", "#713f12","#854d0e","#a16207","#b45309","#d6a96c", "#111827","#374151","#6b7280","#9ca3af","#d1d5db", "#f9fafb","#e5e7eb","#cbd5e1","#94a3b8","#475569"]
                                            delegate: AccentPaletteSwatch { required property string modelData; swatchColor: modelData; selected: Config.appearance.accentOverride === modelData; onActivated: AppearanceService.setAccentOverride(modelData) }
                                        }
                                    }
                                    RowLayout { visible: root.accentPaletteOpen; Layout.fillWidth: true
                                        Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 28; radius: Theme.radiusSmall; color: /^#[0-9a-fA-F]{6}$/.test(accentHex.text) ? accentHex.text : Theme.primary; border.width: 1; border.color: Qt.alpha(Theme.outlineVariant, 0.72) }
                                        TextInput {
                                            id: accentHex
                                            Layout.fillWidth: true
                                            text: ""
                                            selectByMouse: true
                                            color: Theme.surfaceText
                                            font.family: Config.appearance.monoFontFamily
                                            font.pixelSize: 10
                                            validator: RegularExpressionValidator {
                                                regularExpression: /#[0-9a-fA-F]{6}/
                                            }
                                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !accentHex.text && !accentHex.activeFocus; text: "Enter hex value"; color: Theme.surfaceVariantText; font: accentHex.font }
                                            onTextEdited: if (/^#[0-9a-fA-F]{6}$/.test(text)) root.stagedAccent = text.toLowerCase()
                                        }
                                        TextButton { compact: true; text: "Pick"; onClicked: root.pickAccentFromScreen() }
                                        TextButton { compact: true; text: "Cancel"; onClicked: { root.stagedAccent=Config.appearance.accentOverride; root.accentPaletteOpen=false } }
                                        TextButton { compact: true; text: "Select"; enabled: /^#[0-9a-fA-F]{6}$/.test(accentHex.text); onClicked: { AppearanceService.setAccentOverride(root.stagedAccent); root.accentPaletteOpen=false } }
                                    }
                                }
                            }

                            InfoStrip {
                                Layout.fillWidth: true
                                glyph: "󰏘"
                                error: AppearanceService.errorMessage.length > 0
                                accent: AppearanceService.errorMessage.length > 0
                                    ? Theme.error : Theme.primary
                                message: AppearanceService.errorMessage.length > 0
                                    ? AppearanceService.errorMessage
                                    : AppearanceService.statusMessage.length > 0
                                        ? AppearanceService.statusMessage
                                        : "Palette changes update Odyssey and enabled integrations live."
                            }

                        }

                        ColumnLayout {
                            visible: root.section === "idle"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Odyssey idle policy"
                                detail: IdleService.statusLabel
                                contentHeight: 30
                                PreferenceToggleRow {
                                    anchors.fill: parent
                                    label: "Manage Hypridle timing"
                                    checked: Config.idle.managed
                                    onToggled: enabled => IdleService
                                        .setManaged(enabled)
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Idle sequence"
                                detail: "Stages stay ordered so wake and sleep behavior remains predictable"
                                contentHeight: 196
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Dim screen after"
                                        value: Config.idle.dimMinutes
                                        from: 1; to: 999; suffix: "min"
                                        onAdjusted: value => IdleService
                                            .setMetric("dimMinutes", value)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Lock after"
                                        value: Config.idle.lockMinutes
                                        from: 1; to: 999; suffix: "min"
                                        onAdjusted: value => IdleService
                                            .setMetric("lockMinutes", value)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Display off after"
                                        value: Config.idle.displayOffMinutes
                                        from: 1; to: 999; suffix: "min"
                                        onAdjusted: value => IdleService
                                            .setMetric("displayOffMinutes", value)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Suspend after"
                                        value: Config.idle.suspendMinutes
                                        from: 1; to: 999; suffix: "min"
                                        onAdjusted: value => IdleService
                                            .setMetric("suspendMinutes", value)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Hibernate after"
                                        value: Config.idle.hibernateMinutes
                                        from: 1; to: 999; suffix: "min"
                                        onAdjusted: value => IdleService
                                            .setMetric("hibernateMinutes", value)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Dim brightness"
                                        value: Config.idle.dimPercent
                                        from: 5; to: 90; suffix: "%"
                                        onAdjusted: value => IdleService
                                            .setMetric("dimPercent", value)
                                    }
                                }
                            }

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Keep awake"
                                detail: "Prevents dimming, locking, display-off, suspend, and hibernate until disabled"
                                checked: IdleService.inhibited
                                onToggled: enabled => {
                                    if (enabled !== IdleService.inhibited)
                                        IdleService.toggleInhibition()
                                }
                            }

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Power connection sound"
                                detail: Config.idle.powerSoundsEnabled
                                    ? "Play a chime when external power changes"
                                    : "Disabled · power changes remain visual only"
                                checked: Config.idle.powerSoundsEnabled
                                onToggled: enabled => SettingsStore
                                    .setPowerSoundsEnabled(enabled)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: IdleService.resetPolicy()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "displays"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Island placement"
                                detail: Config.displays.islandPolicy === "all"
                                    ? "Each connected display keeps its own Island"
                                    : "One persistent display owns Odyssey surfaces"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    SettingsChoice {
                                        compact: true
                                        label: "All displays"
                                        selected: Config.displays.islandPolicy === "all"
                                        onActivated: HyprlandService
                                            .setIslandPolicy("all")
                                    }
                                    SettingsChoice {
                                        compact: true
                                        label: "Primary only"
                                        selected: Config.displays.islandPolicy === "primary"
                                        onActivated: HyprlandService
                                            .setIslandPolicy("primary")
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Primary display"
                                detail: !HyprlandService.primaryPreferenceAvailable
                                    ? Config.displays.primaryMonitor
                                        + " is disconnected · using "
                                        + HyprlandService.primaryMonitorName
                                    : "Active primary · "
                                        + HyprlandService.primaryMonitorName
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    SettingsChoice {
                                        compact: true
                                        label: "Automatic"
                                        selected: Config.displays.primaryMonitor
                                            === "auto"
                                        onActivated: HyprlandService
                                            .setPrimaryMonitor("auto")
                                    }
                                    Repeater {
                                        model: HyprlandService.connectedMonitors
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.name
                                            selected: Config.displays.primaryMonitor
                                                === modelData.name
                                            onActivated: HyprlandService
                                                .setPrimaryMonitor(modelData.name)
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Monitor behavior"
                                detail: "Focused events follow the active display in All mode. Primary-only mode routes shortcuts, notifications, media, and system feedback to the chosen display."
                                contentHeight: 24
                                Text {
                                    anchors.fill: parent
                                    text: HyprlandService.connectedMonitors.length
                                        + " displays connected · top-center placement"
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    font.family: Config.appearance.fontFamily
                                    font.pixelSize: Theme.textSmall
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: HyprlandService
                                        .resetDisplayPreferences()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "notifications"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Do not disturb"
                                detail: "Silences standard alerts while retaining their history"
                                checked: NotificationService.doNotDisturb
                                onToggled: enabled => NotificationService
                                    .setDoNotDisturb(enabled)
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Island alerts"
                                detail: "Critical alerts can remain visible independently"
                                contentHeight: 68
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Standard notification banners"
                                        checked: Config.notifications.showPopups
                                        onToggled: enabled => NotificationService
                                            .setShowPopups(enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Allow critical alerts"
                                        checked: Config.notifications.allowCriticalAlerts
                                        onToggled: enabled => NotificationService
                                            .setAllowCriticalAlerts(enabled)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Presentation time"
                                detail: "How long the Island keeps each alert visible"
                                contentHeight: 60
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Standard"
                                        value: Config.notifications.timeout / 1000
                                        from: 2; to: 10; suffix: "sec"
                                        onAdjusted: value => NotificationService
                                            .setDuration("timeout", value * 1000)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Critical"
                                        value: Config.notifications.criticalTimeout / 1000
                                        from: 4; to: 15; suffix: "sec"
                                        onAdjusted: value => NotificationService
                                            .setDuration("criticalTimeout", value * 1000)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "History retention"
                                detail: "Older entries are discarded locally when the limit is reached"
                                contentHeight: 36
                                StepperRow {
                                    anchors.fill: parent
                                    label: "Recent items"
                                    value: Config.notifications.historyLimit
                                    from: 20; to: 100; suffix: ""
                                    onAdjusted: value => NotificationService
                                        .setHistoryLimit(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: NotificationService.resetPreferences()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "media"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Track-change presentation"
                                detail: "Briefly surface new playback in the Island"
                                checked: Config.media.enabled
                                onToggled: enabled => MediaService
                                    .setPresentationsEnabled(enabled)
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Presentation time"
                                detail: "How long track changes remain visible"
                                contentHeight: 36
                                StepperRow {
                                    anchors.fill: parent
                                    label: "Track change"
                                    value: Config.media.presentationTimeout / 1000
                                    from: 2; to: 10; suffix: "sec"
                                    onAdjusted: value => MediaService
                                        .setPresentationTimeout(value * 1000)
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Player priority"
                                detail: "Choose how Odyssey responds when multiple players exist"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    SettingsChoice {
                                        compact: true
                                        label: "Keep selected"
                                        selected: !Config.media.preferPlaying
                                        onActivated: MediaService.setPreferPlaying(false)
                                    }
                                    SettingsChoice {
                                        compact: true
                                        label: "Follow playing"
                                        selected: Config.media.preferPlaying
                                        onActivated: MediaService.setPreferPlaying(true)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Hover presence"
                                detail: "Decide when media artwork and metadata use hover space"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "hidden", label: "Hidden" },
                                            { id: "playing", label: "Playing" },
                                            { id: "available", label: "Available" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.media.hoverMode
                                                === modelData.id
                                            onActivated: MediaService
                                                .setHoverMode(modelData.id)
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: MediaService.resetPreferences()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "wallpaper"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Apply selections to"
                                detail: Config.wallpaper.target === "all"
                                    ? "One selection updates every display"
                                    : "Selections affect the display that opened Odyssey"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    SettingsChoice {
                                        compact: true
                                        label: "This display"
                                        selected: Config.wallpaper.target === "current"
                                        onActivated: WallpaperService.setTarget("current")
                                    }
                                    SettingsChoice {
                                        compact: true
                                        label: "All displays"
                                        selected: Config.wallpaper.target === "all"
                                        onActivated: WallpaperService.setTarget("all")
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Transition"
                                detail: Config.appearance.reducedMotion
                                    ? "Reduced Motion applies changes instantly; your selection is saved."
                                    : WallpaperService.backendDetail
                                contentHeight: 104
                                ColumnLayout {
                                    anchors.fill: parent; spacing: Theme.space2
                                    GridLayout { Layout.fillWidth: true; columns: 4; columnSpacing: Theme.space1; rowSpacing: Theme.space1
                                        Repeater { model: [
                                            {id:"fade",label:"Fade"}, {id:"slide",label:"Slide"}, {id:"wipe",label:"Wipe"}, {id:"wave",label:"Wave"},
                                            {id:"expand",label:"Expand"}, {id:"contract",label:"Contract"}, {id:"spotlight",label:"Spotlight"}, {id:"random",label:"Random"}]
                                            delegate: SettingsChoice { required property var modelData; Layout.fillWidth: true; label: modelData.label; selected: Config.wallpaper.transition === modelData.id; onActivated: WallpaperService.setTransition(modelData.id) }
                                        }
                                    }
                                    RowLayout { Layout.fillWidth: true
                                        Text { Layout.fillWidth: true; text: "Duration"; color: Theme.surfaceVariantText; font.family: Config.appearance.fontFamily; font.pixelSize: 10 }
                                        SettingsSlider { Layout.preferredWidth: 164; from: 0.3; to: 2.5; stepSize: 0.1; value: Config.wallpaper.transitionDuration; onAdjusted: value => WallpaperService.setTransitionDuration(value) }
                                        Text { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignHCenter; text: Config.wallpaper.transitionDuration.toFixed(1) + " s"; color: Theme.primary; font.family: Config.appearance.monoFontFamily; font.pixelSize: 9; font.weight: Font.DemiBold }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Gallery density"
                                detail: "Changes browsing density without altering image files"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { columns: 2, label: "Spacious" },
                                            { columns: 3, label: "Balanced" },
                                            { columns: 4, label: "Compact" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.wallpaper.galleryColumns
                                                === modelData.columns
                                            onActivated: WallpaperService
                                                .setGalleryColumns(modelData.columns)
                                        }
                                    }
                                }
                            }

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Library refresh"
                                detail: "Rescan configured image folders when Wallpaper opens"
                                checked: Config.wallpaper.refreshOnOpen
                                onToggled: enabled => WallpaperService
                                    .setRefreshOnOpen(enabled)
                            }

                            InfoStrip {
                                Layout.fillWidth: true
                                glyph: "󰉋"
                                accent: Theme.tertiary
                                message: "Library: ~/wallpaper and ~/Pictures/Wallpapers · Color generation remains independently controlled under Palette."
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: WallpaperService.resetPreferences()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "dashboard"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Overview sections"
                                detail: "The center always retains Media or System for balance"
                                contentHeight: 104
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Calendar, weather, and notification context"
                                        checked: Config.dashboard.showHero
                                        onToggled: enabled => SettingsStore
                                            .setDashboardSection("showHero", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Media card"
                                        checked: Config.dashboard.showMedia
                                        onToggled: enabled => SettingsStore
                                            .setDashboardSection("showMedia", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "System health card"
                                        checked: Config.dashboard.showSystem
                                        onToggled: enabled => SettingsStore
                                            .setDashboardSection("showSystem", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Quick status strip"
                                        checked: Config.dashboard.showQuickStrip
                                        onToggled: enabled => SettingsStore
                                            .setDashboardSection("showQuickStrip", enabled)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Weather location"
                                detail: WeatherService.configured
                                    ? "Saved locally for Open-Meteo forecasts"
                                    : "Unconfigured — no forecast request is made"
                                contentHeight: 70
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space2
                                        WeatherField {
                                            Layout.fillWidth: true
                                            label: "City or label"
                                            value: root.weatherNameDraft
                                            onEdited: value => root.weatherNameDraft = value
                                        }
                                        WeatherField {
                                            Layout.preferredWidth: 112
                                            label: "Latitude"
                                            value: root.weatherLatitudeDraft
                                            onEdited: value => root.weatherLatitudeDraft = value
                                        }
                                        WeatherField {
                                            Layout.preferredWidth: 112
                                            label: "Longitude"
                                            value: root.weatherLongitudeDraft
                                            onEdited: value => root.weatherLongitudeDraft = value
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Item { Layout.fillWidth: true }
                                        TextButton {
                                            compact: true
                                            text: "Clear"
                                            enabled: WeatherService.configured
                                            onClicked: {
                                                SettingsStore.clearWeatherLocation()
                                                root.weatherNameDraft = ""
                                                root.weatherLatitudeDraft = ""
                                                root.weatherLongitudeDraft = ""
                                            }
                                        }
                                        TextButton {
                                            compact: true
                                            text: "Save location"
                                            enabled: root.weatherDraftValid
                                            onClicked: SettingsStore.setWeatherLocation(
                                                root.weatherNameDraft,
                                                root.weatherLatitudeDraft,
                                                root.weatherLongitudeDraft)
                                        }
                                    }
                                }
                            }

                            InfoStrip {
                                Layout.fillWidth: true
                                glyph: "󰕮"
                                message: "Visible sections rebalance automatically inside the existing Dashboard size."
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: SettingsStore.resetDashboard()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "shortcuts"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Hyprland ownership"
                                detail: ShortcutService.statusLabel
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    Text {
                                        Layout.fillWidth: true
                                        text: ShortcutService.installed
                                            ? "Managed and reversible" : "Manual"
                                        color: ShortcutService.errorMessage.length > 0
                                            ? Theme.error : Theme.surfaceText
                                        font.family: Config.appearance.fontFamily
                                        font.pixelSize: Theme.textSmall
                                    }
                                    SettingsToggle {
                                        checked: ShortcutService.installed
                                        available: !ShortcutService.busy
                                        onToggled: enabled => ShortcutService
                                            .setManaged(enabled)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Odyssey actions"
                                detail: "Disabled actions remain available from the shell itself"
                                contentHeight: ShortcutService.entries.length * 36
                                    + (ShortcutService.entries.length - 1)
                                        * Theme.space1
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Repeater {
                                        model: ShortcutService.entries
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            spacing: Theme.space2
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                elide: Text.ElideRight
                                                color: Theme.surfaceText
                                                font.family: Config.appearance.fontFamily
                                                font.pixelSize: Theme.textSmall
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: 112
                                                Layout.preferredHeight: 26
                                                radius: Theme.radiusSmall
                                                color: Theme.surfaceContainerHigh
                                                border.width: 1
                                                border.color: Qt.alpha(
                                                    Theme.outlineVariant, 0.48)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.keys
                                                    color: Theme.primary
                                                    font.family: Config.appearance
                                                        .monoFontFamily
                                                    font.pixelSize: 8
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                            SettingsToggle {
                                                checked: ShortcutService
                                                    .enabled(modelData.id)
                                                available: !ShortcutService.busy
                                                onToggled: enabled => ShortcutService
                                                    .setEnabled(modelData.id, enabled)
                                            }
                                        }
                                    }
                                }
                            }

                            InfoStrip {
                                Layout.fillWidth: true
                                glyph: "󰌌"
                                message: "Enabling management writes only Odyssey bindings inside Odyssey's owned Hyprland integration. Turning it off removes those bindings and keeps the startup hook."
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    enabled: !ShortcutService.busy
                                    opacity: enabled ? 1 : 0.42
                                    onClicked: ShortcutService.resetPreferences()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "island"
                                && root.islandEditor === "overview"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            SettingsActionCard {
                                Layout.fillWidth: true
                                title: "Island geometry"
                                detail: "Live placement · " + Config.island.dormantWidth
                                    + " / " + Config.island.hoverWidth + " / "
                                    + Config.island.expandedWidth + " px"
                                actionText: "Live edit"
                                onActivated: {
                                    root.pillPreviewMode = "rest"
                                    root.islandEditor = "geometry"
                                    settingsScroll.contentY = 0
                                }
                            }

                            SettingsActionCard {
                                Layout.fillWidth: true
                                title: "Resting & Hover Island"
                                detail: Config.island.restItemOrder.length
                                    + " resting · " + Config.island.hoverItemOrder.length
                                    + " hover items · order, spacing, and scale"
                                actionText: "Edit items"
                                onActivated: {
                                    root.pillPreviewMode = "rest"
                                    root.islandEditor = "content"
                                    settingsScroll.contentY = 0
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Clock format"
                                detail: "Applies to the resting pill, hover view, and shell clock"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    Item { Layout.fillWidth: true }
                                    SettingsChoice {
                                        compact: true
                                        label: "12 hour"
                                        selected: !Config.appearance.use24HourClock
                                        onActivated: SettingsStore.setClock24Hour(false)
                                    }
                                    SettingsChoice {
                                        compact: true
                                        label: "24 hour"
                                        selected: Config.appearance.use24HourClock
                                        onActivated: SettingsStore.setClock24Hour(true)
                                    }
                                }
                            }

                            SettingsCard {
                                visible: false
                                Layout.fillWidth: true
                                title: "Resting pill content"
                                detail: "Choose which glanceable items remain visible at rest"
                                contentHeight: 148
                                GridLayout {
                                    anchors.fill: parent
                                    columns: 2
                                    columnSpacing: Theme.space4
                                    rowSpacing: Theme.space2
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Weather"
                                        checked: Config.island.restShowWeather
                                        onToggled: enabled => root.setIslandItem(
                                            "rest", "Weather", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Do not disturb"
                                        checked: Config.island.restShowDnd
                                        onToggled: enabled => root.setIslandItem(
                                            "rest", "Dnd", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Keep awake"
                                        checked: Config.island.restShowKeepAwake
                                        onToggled: enabled => root.setIslandItem(
                                            "rest", "KeepAwake", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Power profile"
                                        checked: Config.island.restShowPowerProfile
                                        onToggled: enabled => root.setIslandItem(
                                            "rest", "PowerProfile", enabled)
                                    }
                                }
                            }

                            SettingsCard {
                                visible: false
                                Layout.fillWidth: true
                                title: "Hover pill content"
                                detail: "Add or remove status groups from the expanded glance"
                                contentHeight: 148
                                GridLayout {
                                    anchors.fill: parent
                                    columns: 2
                                    columnSpacing: Theme.space4
                                    rowSpacing: Theme.space2
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Workspaces"
                                        checked: Config.island.hoverShowWorkspaces
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Workspaces", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Clock & date"
                                        checked: Config.island.hoverShowClock
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Clock", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Audio"
                                        checked: Config.island.hoverShowAudio
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Audio", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Network"
                                        checked: Config.island.hoverShowNetwork
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Network", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Do not disturb"
                                        checked: Config.island.hoverShowDnd
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Dnd", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Bluetooth"
                                        checked: Config.island.hoverShowBluetooth
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Bluetooth", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Keep awake"
                                        checked: Config.island.hoverShowKeepAwake
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "KeepAwake", enabled)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Battery"
                                        checked: Config.island.hoverShowBattery
                                        onToggled: enabled => root.setIslandItem(
                                            "hover", "Battery", enabled)
                                    }
                                }
                            }

                            SettingsCard {
                                visible: false
                                Layout.fillWidth: true
                                title: "Item spacing"
                                detail: "Set the breathing room between visible pill items"
                                contentHeight: 72
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Resting pill"
                                        value: Config.island.restItemSpacing
                                        from: 2; to: 18
                                        onAdjusted: value => root
                                            .setIslandSpacing("rest", value)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Hover pill"
                                        value: Config.island.hoverItemSpacing
                                        from: 2; to: 20
                                        onAdjusted: value => root
                                            .setIslandSpacing("hover", value)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Auto hide"
                                detail: Config.island.autoHide
                                    ? (Config.island.showRevealLip
                                        ? "Leaves a four-pixel reveal edge at the top of the display"
                                        : "Keeps the top-edge invisible until revealed")
                                    : "The resting pill remains visible"
                                headerToggleVisible: true
                                headerChecked: Config.island.autoHide
                                onHeaderToggled: enabled => SettingsStore
                                    .setIslandAutoHide(enabled)
                                contentHeight: 60
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Lip"
                                        checked: Config.island.showRevealLip
                                        available: Config.island.autoHide
                                        onToggled: enabled => SettingsStore
                                            .setIslandRevealLip(enabled)
                                    }
                                    StepperRow {
                                        Layout.fillWidth: true
                                        label: "Hide after"
                                        value: Config.island.autoHideDelay / 1000
                                        from: 1; to: 10; suffix: "sec"
                                        available: Config.island.autoHide
                                        onAdjusted: value => SettingsStore
                                            .setIslandMetric("autoHideDelay",
                                                value * 1000)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Surface density"
                                detail: "Adjust shared spacing without changing type size"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "compact", label: "Compact" },
                                            { id: "balanced", label: "Balanced" },
                                            { id: "airy", label: "Airy" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.appearance.density
                                                === modelData.id
                                            onActivated: AppearanceService
                                                .setDensity(modelData.id)
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Corner character"
                                detail: "Affects shared cards, controls, and expanded surfaces"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "subtle", label: "Subtle" },
                                            { id: "balanced", label: "Balanced" },
                                            { id: "round", label: "Round" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.appearance.cornerStyle
                                                === modelData.id
                                            onActivated: AppearanceService
                                                .setCornerStyle(modelData.id)
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Animation"
                                detail: "Controls morphs, fades, and feedback timing"
                                inlineLayout: true
                                contentHeight: 36
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space1
                                    Item { Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "quick", label: "Quick" },
                                            { id: "balanced", label: "Balanced" },
                                            { id: "calm", label: "Calm" }
                                        ]
                                        delegate: SettingsChoice {
                                            required property var modelData
                                            compact: true
                                            label: modelData.label
                                            selected: Config.appearance.motionSpeed
                                                === modelData.id
                                            available: !Config.appearance.reducedMotion
                                            onActivated: AppearanceService
                                                .setMotionSpeed(modelData.id)
                                        }
                                    }
                                }
                            }

                            HeaderToggleCard {
                                Layout.fillWidth: true
                                title: "Reduce motion"
                                detail: "Minimizes Island morphs, fades, and animated feedback"
                                checked: Config.appearance.reducedMotion
                                onToggled: enabled => AppearanceService
                                    .setReducedMotion(enabled)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                TextButton {
                                    text: "Reset"
                                    onClicked: AppearanceService.resetIslandAndMotion()
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "island"
                                && root.islandEditor === "geometry"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            RowLayout {
                                Layout.fillWidth: true
                                TextButton {
                                    text: "‹ Back"
                                    onClicked: root.islandEditor = "overview"
                                }
                                Item { Layout.fillWidth: true }
                                SettingsChoice {
                                    Layout.preferredWidth: 78
                                    label: "Resting"
                                    selected: root.pillPreviewMode === "rest"
                                    onActivated: root.pillPreviewMode = "rest"
                                }
                                SettingsChoice {
                                    Layout.preferredWidth: 78
                                    label: "Hover"
                                    selected: root.pillPreviewMode === "hover"
                                    onActivated: root.pillPreviewMode = "hover"
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Screen placement"
                                detail: "Position the Island and reserve clear workspace below it"
                                contentHeight: 52
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Top gap"
                                        value: Config.island.topMargin
                                        from: 0; to: 16
                                        onAdjusted: value => AppearanceService
                                            .setIslandMetric("topMargin", value)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Workspace clearance"
                                        value: Config.island.reservedSpace
                                        from: 26; to: 52
                                        onAdjusted: value => AppearanceService
                                            .setIslandMetric("reservedSpace", value)
                                    }
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: "Island widths"
                                detail: "The live preview above follows the selected resting or hover state"
                                contentHeight: 80
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Resting width"
                                        value: Config.island.dormantWidth
                                        from: 214; to: 320
                                        onAdjusted: value => AppearanceService
                                            .setIslandMetric("dormantWidth", value)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Hover width"
                                        value: Config.island.hoverWidth
                                        from: 470; to: 760
                                        onAdjusted: value => AppearanceService
                                            .setIslandMetric("hoverWidth", value)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Expanded width"
                                        value: Config.island.expandedWidth
                                        from: 620; to: 900
                                        onAdjusted: value => AppearanceService
                                            .setIslandMetric("expandedWidth", value)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "island"
                                && root.islandEditor === "content"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            RowLayout {
                                Layout.fillWidth: true
                                TextButton {
                                    text: "‹ Back"
                                    onClicked: root.islandEditor = "overview"
                                }
                                Item { Layout.fillWidth: true }
                                SettingsChoice {
                                    Layout.preferredWidth: 84
                                    label: "Resting"
                                    selected: root.pillPreviewMode === "rest"
                                    onActivated: root.pillPreviewMode = "rest"
                                }
                                SettingsChoice {
                                    Layout.preferredWidth: 84
                                    label: "Hover"
                                    selected: root.pillPreviewMode === "hover"
                                    onActivated: root.pillPreviewMode = "hover"
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: root.pillPreviewMode === "rest"
                                    ? "Resting Island items" : "Hover Island items"
                                detail: root.pillPreviewMode === "rest"
                                    ? "Arrange the surrounding resting items"
                                    : "Drag items into slots, between slots, or into remove"
                                contentHeight: root.pillPreviewMode === "rest" ? 185 : 224
                                IslandOrderEditor {
                                    anchors.fill: parent
                                    context: root.pillPreviewMode
                                }
                            }

                            SettingsCard {
                                Layout.fillWidth: true
                                title: root.pillPreviewMode === "rest"
                                    ? "Resting spacing & scale"
                                    : "Hover spacing & scale"
                                detail: root.pillPreviewMode === "rest"
                                    ? "Tune resting spacing, text, and icon scale"
                                    : "Spacing is automatically limited when the chosen width is full"
                                contentHeight: 110
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space2
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Item spacing"
                                        value: root.pillPreviewMode === "rest"
                                            ? Config.island.restItemSpacing
                                            : Config.island.hoverItemSpacing
                                        from: 2
                                        to: root.pillPreviewMode === "rest" ? 18 : 20
                                        onAdjusted: value => root.setIslandSpacing(
                                            root.pillPreviewMode, value)
                                    }
                                    PreferenceToggleRow {
                                        Layout.fillWidth: true
                                        label: "Sync text and icons"
                                        checked: root.pillPreviewMode === "rest"
                                            ? Config.island.restScaleSynced
                                            : Config.island.hoverScaleSynced
                                        onToggled: enabled => SettingsStore
                                            .setIslandContentSync(
                                                root.pillPreviewMode, enabled)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Text size"
                                        value: (root.pillPreviewMode === "rest"
                                            ? Config.island.restTextScale
                                            : Config.island.hoverTextScale) * 100
                                        from: 80; to: 130; suffix: "%"
                                        onAdjusted: value => SettingsStore
                                            .setIslandContentScale(
                                                root.pillPreviewMode, "text", value)
                                    }
                                    MetricRow {
                                        Layout.fillWidth: true
                                        label: "Icon size"
                                        value: (root.pillPreviewMode === "rest"
                                            ? Config.island.restIconScale
                                            : Config.island.hoverIconScale) * 100
                                        from: 80; to: 130; suffix: "%"
                                        onAdjusted: value => SettingsStore
                                            .setIslandContentScale(
                                                root.pillPreviewMode, "icon", value)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.section === "integrations"
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            IntegrationRow {
                                Layout.fillWidth: true
                                name: "Odyssey shell"
                                detail: "Wallpaper-derived semantic colors"
                                integrationEnabled: Config.appearance.wallpaperPaletteEnabled
                                available: true
                                managed: true
                                onToggleRequested: enabled =>
                                    AppearanceService.setOdysseyPaletteEnabled(enabled)
                            }
                            IntegrationRow {
                                Layout.fillWidth: true
                                name: "Hyprlock"
                                detail: "Odyssey palette, wallpaper, and lock layout"
                                integrationEnabled: Config.externalThemes.hyprlockEnabled
                                available: !AppearanceService.changingIntegration
                                managed: true
                                onToggleRequested: enabled =>
                                    AppearanceService.setHyprlockEnabled(enabled)
                            }
                            IntegrationRow { Layout.fillWidth: true; name: "Hyprland"; detail: "Window borders and compositor colors" }
                            IntegrationRow { Layout.fillWidth: true; name: "GTK / Thunar"; detail: "Application toolkit theme" }
                            IntegrationRow { Layout.fillWidth: true; name: "Qt"; detail: "Qt application color scheme" }
                            IntegrationRow {
                                Layout.fillWidth: true
                                name: "Terminal tools"
                                detail: "Kitty, Starship, and Fastfetch palettes"
                                integrationEnabled: AppearanceService.terminalThemesEnabled
                                available: AppearanceService.terminalThemesReady
                                    && !AppearanceService.changingIntegration
                                managed: true
                                onToggleRequested: enabled => AppearanceService
                                    .setTerminalThemesEnabled(enabled)
                            }

                            InfoStrip {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.space1
                                glyph: "󰋼"
                                message: "Manual means Odyssey leaves that target untouched. Managed targets use reversible ownership records and refuse conflicting external edits."
                            }
                        }
                    }
                }
            }
        }
    }

    component SettingsCard: Rectangle {
        id: card
        property string title: ""
        property string detail: ""
        property real contentHeight: 40
        property bool inlineLayout: false
        property bool headerToggleVisible: false
        property bool headerChecked: false
        property bool headerToggleAvailable: true
        signal headerToggled(bool enabled)
        default property alias content: contentHost.data
        implicitHeight: inlineLayout
            ? Math.max(cardHeader.implicitHeight, contentHeight) + Theme.space2 * 2
            : cardHeader.implicitHeight + contentHeight + Theme.space2 * 3
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.surfaceContainerHigh,
            Theme.dark ? 0.58 : 0.48)
        border.width: 1
        border.color: Qt.alpha(Theme.outlineVariant, 0.28)

        GridLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            anchors.topMargin: Theme.space2
            anchors.bottomMargin: Theme.space2
            columns: card.inlineLayout ? 2 : 1
            columnSpacing: Theme.space3
            rowSpacing: Theme.space2
            RowLayout {
                id: cardHeader
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.space2
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: card.title
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.detail
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
                SettingsToggle {
                    visible: card.headerToggleVisible
                    checked: card.headerChecked
                    available: card.headerToggleAvailable
                    onToggled: enabled => card.headerToggled(enabled)
                }
            }
            Item {
                id: contentHost
                Layout.fillWidth: !card.inlineLayout
                Layout.preferredWidth: card.inlineLayout
                    ? Math.min(250, card.width * 0.52) : -1
                Layout.preferredHeight: card.contentHeight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    component SettingsActionCard: Rectangle {
        id: actionCard
        property string title: ""
        property string detail: ""
        property string actionText: ""
        signal activated()
        implicitHeight: 52
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.surfaceContainerHigh,
            Theme.dark ? 0.42 : 0.34)
        border.width: 1
        border.color: Qt.alpha(Theme.outlineVariant, 0.28)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: actionCard.title
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: actionCard.detail
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
            TextButton {
                text: actionCard.actionText
                compact: true
                onClicked: actionCard.activated()
            }
        }
    }

    component AccentSwatch: Rectangle {
        id: swatch
        property color swatchColor: Theme.primary
        property string glyph: ""
        property bool selected: false
        signal activated()
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        radius: width / 2
        color: swatch.swatchColor
        border.width: swatch.selected || swatch.activeFocus ? 2 : 1
        border.color: swatch.selected || swatch.activeFocus
            ? Theme.surfaceText : Qt.alpha(Theme.outlineVariant, 0.72)
        activeFocusOnTab: true

        Text {
            anchors.centerIn: parent
            visible: swatch.glyph.length > 0
            text: swatch.glyph
            color: Theme.foregroundFor(swatch.swatchColor)
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Theme.iconSmall
        }
        Keys.onReturnPressed: swatch.activated()
        Keys.onEnterPressed: swatch.activated()
        Keys.onSpacePressed: swatch.activated()
        TapHandler {
            onTapped: {
                swatch.forceActiveFocus()
                swatch.activated()
            }
        }
    }

    component AccentPaletteSwatch: Rectangle {
        id: paletteSwatch
        property color swatchColor: Theme.primary
        property bool selected: false
        signal activated()
        Layout.preferredWidth: 31
        Layout.preferredHeight: 22
        radius: 5
        color: swatchColor
        border.width: selected || activeFocus ? 2 : 1
        border.color: selected || activeFocus ? Theme.surfaceText
            : Qt.alpha(Theme.outlineVariant, 0.72)
        activeFocusOnTab: true
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        TapHandler { onTapped: { paletteSwatch.forceActiveFocus(); paletteSwatch.activated() } }
    }

    component InfoStrip: Rectangle {
        id: infoStrip
        property string glyph: "󰋼"
        property string message: ""
        property color accent: Theme.primary
        property bool error: false
        implicitHeight: Math.max(44, infoMessage.implicitHeight
            + Theme.space2 * 2)
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.primaryContainer, 0.16)
        border.width: 1
        border.color: Qt.alpha(accent, 0.30)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space2
            spacing: Theme.space2
            Text {
                text: infoStrip.glyph
                color: infoStrip.accent
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: Theme.iconSmall
            }
            Text {
                id: infoMessage
                Layout.fillWidth: true
                text: infoStrip.message
                color: infoStrip.error ? Theme.error : Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }
        }
    }

    component HeaderToggleCard: Rectangle {
        id: headerToggle
        property string title: ""
        property string detail: ""
        property bool checked: false
        signal toggled(bool enabled)
        implicitHeight: 52
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.surfaceContainerHigh,
            Theme.dark ? 0.42 : 0.34)
        border.width: 1
        border.color: Qt.alpha(Theme.outlineVariant, 0.28)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: headerToggle.title
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: headerToggle.detail
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
            SettingsToggle {
                checked: headerToggle.checked
                onToggled: enabled => headerToggle.toggled(enabled)
            }
        }
    }

    component StepperRow: RowLayout {
        id: stepperRow
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property string suffix: ""
        property bool available: true
        signal adjusted(real value)
        enabled: available
        opacity: available ? 1 : 0.38
        spacing: Theme.space2
        Text {
            Layout.fillWidth: true
            text: stepperRow.label
            color: Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textSmall
            elide: Text.ElideRight
        }
        SettingsStepper {
            Layout.preferredWidth: implicitWidth
            from: stepperRow.from
            to: stepperRow.to
            value: stepperRow.value
            stepSize: stepperRow.stepSize
            suffix: stepperRow.suffix
            available: stepperRow.available
            onAdjusted: value => stepperRow.adjusted(value)
        }
    }

    component MetricRow: RowLayout {
        id: metric
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 100
        property bool available: true
        property bool editable: false
        property string suffix: " px"
        property real valueWidth: 44
        property real sliderWidth: 164
        signal adjusted(real value)
        enabled: available
        opacity: available ? 1 : 0.38
        spacing: Theme.space2
        Text {
            Layout.fillWidth: true
            text: metric.label
            color: Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textSmall
            elide: Text.ElideRight
        }
        SettingsSlider {
            Layout.preferredWidth: metric.sliderWidth
            Layout.maximumWidth: metric.sliderWidth
            from: metric.from
            to: metric.to
            value: metric.value
            available: metric.available
            stepSize: 1
            onAdjusted: value => metric.adjusted(value)
        }
        Rectangle {
            visible: !metric.editable
            Layout.preferredWidth: metric.valueWidth
            Layout.preferredHeight: 22
            radius: Theme.radiusSmall
            color: Qt.alpha(Theme.surfaceContainer, 0.72)
            Text {
                anchors.centerIn: parent
                text: Math.round(metric.value) + metric.suffix
                color: Theme.primary
                font.family: Config.appearance.monoFontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }
        Rectangle {
            visible: metric.editable
            Layout.preferredWidth: visible ? metric.valueWidth : 0
            Layout.preferredHeight: 22
            radius: Theme.radiusSmall
            color: valueInput.activeFocus
                ? Qt.alpha(Theme.primaryContainer, 0.42)
                : Qt.alpha(Theme.surfaceContainerHigh, 0.72)
            border.width: 1
            border.color: valueInput.activeFocus
                ? Theme.primary : Qt.alpha(Theme.outlineVariant, 0.54)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space1
                anchors.rightMargin: Theme.space1
                spacing: 2
                TextInput {
                    id: valueInput
                    property bool cancelEdit: false
                    Layout.fillWidth: true
                    color: Theme.primary
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerText
                    horizontalAlignment: TextInput.AlignRight
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator {
                        bottom: Math.ceil(metric.from)
                        top: Math.floor(metric.to)
                    }
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    function restoreValue(): void {
                        text = Math.round(metric.value).toString()
                    }
                    function commitValue(): void {
                        const nextValue = Number(text)
                        if (acceptableInput && Number.isFinite(nextValue))
                            metric.adjusted(nextValue)
                    }
                    onActiveFocusChanged: {
                        if (activeFocus)
                            selectAll()
                        else {
                            if (!cancelEdit)
                                commitValue()
                            cancelEdit = false
                            restoreValue()
                        }
                    }
                    onAccepted: focus = false
                    Keys.onEscapePressed: event => {
                        cancelEdit = true
                        focus = false
                        event.accepted = true
                    }
                    Component.onCompleted: restoreValue()
                }
                Connections {
                    target: metric
                    function onValueChanged(): void {
                        if (!valueInput.activeFocus)
                            valueInput.restoreValue()
                    }
                }
                Text {
                    text: metric.suffix.trim()
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                }
            }

            Behavior on color { ColorAnimation { duration: Animations.fast } }
            Behavior on border.color { ColorAnimation { duration: Animations.fast } }
        }
    }

    component WeatherField: Rectangle {
        id: weatherField
        property string label: ""
        property string value: ""
        signal edited(string value)
        implicitHeight: 32
        radius: Theme.radiusSmall
        color: weatherInput.activeFocus
            ? Qt.alpha(Theme.primaryContainer, 0.36)
            : Qt.alpha(Theme.surfaceContainerHigh, 0.60)
        border.width: 1
        border.color: weatherInput.activeFocus
            ? Theme.primary : Qt.alpha(Theme.outlineVariant, 0.42)

        TextInput {
            id: weatherInput
            anchors.fill: parent
            anchors.leftMargin: Theme.space2
            anchors.rightMargin: Theme.space2
            text: weatherField.value
            color: Theme.surfaceText
            selectionColor: Theme.primaryContainer
            selectedTextColor: Theme.primaryContainerText
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            font.family: Config.appearance.fontFamily
            font.pixelSize: 10
            onTextEdited: weatherField.edited(text)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: weatherInput.text.length === 0
                    && !weatherInput.activeFocus
                text: weatherField.label
                color: Theme.surfaceVariantText
                font: weatherInput.font
            }
        }
    }

    component PreferenceToggleRow: RowLayout {
        id: preference
        property string label: ""
        property bool checked: false
        property bool available: true
        signal toggled(bool enabled)
        enabled: available
        opacity: available ? 1 : 0.42
        spacing: Theme.space2
        Text {
            Layout.fillWidth: true
            text: preference.label
            color: Theme.surfaceText
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.textSmall
            elide: Text.ElideRight
        }
        SettingsToggle {
            checked: preference.checked
            available: preference.available
            onToggled: enabled => preference.toggled(enabled)
        }
    }

    component IntegrationRow: Rectangle {
        id: integration
        property string name: ""
        property string detail: ""
        property bool integrationEnabled: false
        property bool available: false
        property bool managed: false
        signal toggleRequested(bool enabled)
        implicitHeight: 56
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.surfaceContainerHigh,
            Theme.dark ? 0.42 : 0.34)
        border.width: 1
        border.color: Qt.alpha(Theme.outlineVariant, 0.28)
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space3
            spacing: Theme.space2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: integration.name
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: integration.detail
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                visible: !integration.managed
                Layout.preferredWidth: 58
                Layout.preferredHeight: 24
                radius: 12
                color: Theme.surfaceContainerHigh
                Text {
                    anchors.centerIn: parent
                    text: "MANUAL"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }
            SettingsToggle {
                visible: integration.managed
                checked: integration.integrationEnabled
                available: integration.available
                onToggled: checked => integration.toggleRequested(checked)
            }
        }
    }
}
