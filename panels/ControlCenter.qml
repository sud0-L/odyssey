import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property string expandedSection: ""
    property string displayedSection: ""
    property string pendingSection: ""
    property real detailProgress: 0
    property bool detailTransitionActive: false
    property real detailContentOpacity: 0
    property var wifiCredentialNetwork: null
    property string wifiPassword: ""
    property var informationOption: null
    property bool wifiAutomatic: true
    property bool wifiModeStaged: false
    property string automaticWifiDnsServers: ""
    property string manualWifiDnsServers: ""
    property string manualWifiAddress: ""
    property string manualWifiGateway: ""
    readonly property bool detailOpen: expandedSection !== ""
    readonly property bool wifiCredentialsActive: displayedSection === "wifi"
        && wifiCredentialNetwork !== null
    readonly property bool informationViewActive: informationOption !== null
    readonly property bool detailSubviewActive: wifiCredentialsActive || informationViewActive
    readonly property var detailModel: {
        if (displayedSection === "output")
            return AudioService.outputDevices.slice(0, Config.controlCenter.detailResultLimit)
        if (displayedSection === "input")
            return AudioService.inputDevices.slice(0, Config.controlCenter.detailResultLimit)
        if (displayedSection === "wifi") {
            const networks = NetworkService.wifiNetworks.slice()
            networks.sort((a, b) => Number(b.connected) - Number(a.connected)
                || Number(b.known) - Number(a.known)
                || (b.signalStrength || 0) - (a.signalStrength || 0))
            return networks
        }
        if (displayedSection === "bluetooth")
            return BluetoothService.discoverableDevices
        return []
    }

    function toggleSection(section: string): void {
        if (expandedSection === section) {
            closeExpandedSection()
            return
        }
        detailMotionDone.stop()
        if (detailOpen) {
            pendingSection = section
            detailSwap.restart()
            return
        }
        detailSwap.stop()
        displayedSection = section
        clearWifiCredentials()
        clearInformationView()
        expandedSection = section
        detailContentOpacity = 1
        detailTransitionActive = true
        detailProgress = 1
        detailMotionDone.restart()
    }

    function closeExpandedSection(): bool {
        if (detailSubviewActive) {
            closeDetailSubview()
            return true
        }
        if (!detailOpen)
            return false
        detailSwap.stop()
        pendingSection = ""
        clearWifiCredentials()
        clearInformationView()
        expandedSection = ""
        detailContentOpacity = 0
        detailTransitionActive = true
        detailProgress = 0
        detailMotionDone.restart()
        return true
    }

    function resetDetails(): void {
        detailSwap.stop()
        detailMotionDone.stop()
        pendingSection = ""
        clearWifiCredentials()
        clearInformationView()
        expandedSection = ""
        displayedSection = ""
        detailContentOpacity = 0
        detailProgress = 0
        detailTransitionActive = false
    }

    function detailTitle(): string {
        if (displayedSection === "output")
            return "Audio output"
        if (displayedSection === "input")
            return "Microphone input"
        if (displayedSection === "wifi")
            return "Wi-Fi networks"
        if (displayedSection === "bluetooth")
            return "Bluetooth devices"
        return ""
    }

    function optionTitle(option): string {
        if (displayedSection === "output" || displayedSection === "input")
            return AudioService.displayName(option, "Audio device")
        if (displayedSection === "wifi")
            return option?.name || "Unnamed network"
        return BluetoothService.deviceName(option)
    }

    function optionDetail(option): string {
        if (displayedSection === "output")
            return option?.id === AudioService.sink?.id ? "Current output" : "Select output"
        if (displayedSection === "input")
            return option?.id === AudioService.source?.id ? "Current input" : "Select input"
        if (displayedSection === "wifi") {
            if (option?.connected)
                return "Connected"
            if (option?.stateChanging)
                return "Connecting…"
            const strength = Math.round((option?.signalStrength || 0) * 100) + "%"
            if (option?.known)
                return "Saved · " + strength
            return NetworkService.securityLabel(option) + " · " + strength
        }
        if (option?.connected) {
            const battery = option.batteryAvailable
                ? " · " + Math.round(option.battery * 100) + "%" : ""
            return "Connected" + battery
        }
        if (option?.pairing)
            return "Pairing…"
        return option?.paired || option?.bonded ? "Connect" : "Pair"
    }

    function optionSelected(option): bool {
        if (displayedSection === "output")
            return option?.id === AudioService.sink?.id
        if (displayedSection === "input")
            return option?.id === AudioService.source?.id
        return option?.connected ?? false
    }

    function optionAvailable(option): bool {
        if (displayedSection === "wifi")
            return NetworkService.canSelectNetwork(option)
        if (displayedSection === "bluetooth")
            return option !== null && option !== undefined && !option.blocked
        return option !== null && option !== undefined
    }

    function activateOption(option): void {
        if (displayedSection === "output")
            AudioService.setOutputDevice(option)
        else if (displayedSection === "input")
            AudioService.setInputDevice(option)
        else if (displayedSection === "wifi") {
            if (NetworkService.requiresPassword(option)) {
                wifiCredentialNetwork = option
                wifiPassword = ""
                Qt.callLater(() => wifiPasswordInput.forceActiveFocus())
            } else {
                NetworkService.selectWifiNetwork(option)
            }
        }
        else if (displayedSection === "bluetooth")
            BluetoothService.activateDevice(option)
    }

    function clearWifiCredentials(): void {
        wifiCredentialNetwork = null
        wifiPassword = ""
    }

    function clearInformationView(): void {
        informationOption = null
        NetworkService.closeActiveWifiProfile()
    }

    function closeDetailSubview(): void {
        clearWifiCredentials()
        clearInformationView()
    }

    function showInformation(option): void {
        if (!option || (displayedSection !== "wifi" && displayedSection !== "bluetooth"))
            return
        clearWifiCredentials()
        if (displayedSection === "wifi" && !NetworkService.openActiveWifiProfile(option))
            return
        informationOption = option
        if (displayedSection === "wifi") {
            wifiModeStaged = false
            syncWifiDnsProfile()
        }
    }

    function informationTitle(): string {
        return informationOption ? optionTitle(informationOption) : detailTitle()
    }

    function informationRows(): var {
        const option = informationOption
        if (!option)
            return []
        if (displayedSection === "wifi") {
            return [
                { label: "Status", value: option.connected ? "Connected"
                    : option.known ? "Saved" : "Available" },
                { label: "Signal", value: Math.round((option.signalStrength || 0) * 100) + "%" },
                { label: "Security", value: NetworkService.securityLabel(option) },
                { label: "Profile", value: option.known ? "Remembered" : "Not saved" }
            ]
        }
        return [
            { label: "Status", value: option.connected ? "Connected"
                : option.paired || option.bonded ? "Paired" : "Nearby" },
            { label: "Address", value: option.address || "Unavailable" },
            { label: "Trusted", value: option.trusted ? "Yes" : "No" },
            { label: "Battery", value: option.batteryAvailable
                ? Math.round(option.battery * 100) + "%" : "Unavailable" }
        ]
    }

    function submitWifiPassword(): void {
        if (!wifiCredentialNetwork || wifiPassword.length < 8)
            return
        if (NetworkService.selectWifiNetwork(wifiCredentialNetwork, wifiPassword))
            clearWifiCredentials()
    }

    function syncWifiDnsProfile(): void {
        const profileAutomatic = NetworkService.wifiProfile.automaticAddress
            && NetworkService.wifiProfile.automaticDns
        if (!wifiModeStaged)
            wifiAutomatic = profileAutomatic
        automaticWifiDnsServers = NetworkService.wifiRuntime.dnsServers
            || NetworkService.wifiProfile.automaticDnsServers
            || NetworkService.wifiProfile.manualDnsServers || "Unavailable"
        if (wifiAutomatic || manualWifiDnsServers.length === 0)
            manualWifiDnsServers = NetworkService.wifiProfile.manualDnsServers || ""
        if (wifiAutomatic || manualWifiAddress.length === 0)
            manualWifiAddress = NetworkService.wifiRuntime.address
                || (NetworkService.wifiProfile.address === "Unavailable"
                    ? "" : NetworkService.wifiProfile.address || "")
        if (wifiAutomatic || manualWifiGateway.length === 0)
            manualWifiGateway = NetworkService.wifiRuntime.gateway
                || (NetworkService.wifiProfile.gateway === "Unavailable"
                    ? "" : NetworkService.wifiProfile.gateway || "")
    }

    function toggleWifiMode(): void {
        if (NetworkService.wifiProfileSaving)
            return
        if (wifiAutomatic) {
            if (manualWifiDnsServers.length === 0)
                manualWifiDnsServers = automaticWifiDnsServers === "Unavailable"
                    ? "" : automaticWifiDnsServers
            manualWifiAddress = NetworkService.wifiRuntime.address
                || manualWifiAddress
            manualWifiGateway = NetworkService.wifiRuntime.gateway
                || manualWifiGateway
            wifiAutomatic = false
            wifiModeStaged = true
            return
        }
        manualAddressSave.stop()
        if (NetworkService.applyActiveWifiAutomatic()) {
            wifiAutomatic = true
            wifiModeStaged = false
        }
    }

    function saveManualWifiDns(): void {
        if (!wifiAutomatic
                && NetworkService.applyActiveWifiDns(
                    false, manualWifiDnsServers))
            wifiModeStaged = false
    }

    function saveManualWifiAddress(): void {
        if (!wifiAutomatic)
            manualAddressSave.restart()
    }

    function validIpv4(value: string): bool {
        return NetworkService.ipv4Number(value) >= 0
    }

    function setDiscoveryForSection(section: string): void {
        NetworkService.setScanning(section === "wifi")
        BluetoothService.setDiscovering(section === "bluetooth")
    }

    function toggleDiscovery(): void {
        if (displayedSection === "wifi")
            NetworkService.setScanning(!NetworkService.scanning)
        else if (displayedSection === "bluetooth")
            BluetoothService.setDiscovering(!BluetoothService.discovering)
    }

    onExpandedSectionChanged: setDiscoveryForSection(expandedSection)

    Timer {
        id: manualAddressSave
        interval: 140
        onTriggered: {
            if (!root.wifiAutomatic
                    && NetworkService.applyActiveWifiAddress(
                        root.manualWifiAddress, root.manualWifiGateway))
                root.wifiModeStaged = false
        }
    }

    Connections {
        target: NetworkService
        function onWifiProfileChanged() {
            if (root.informationViewActive && root.displayedSection === "wifi") {
                root.syncWifiDnsProfile()
            }
        }
        function onWifiRuntimeChanged() {
            if (root.informationViewActive && root.displayedSection === "wifi")
                root.syncWifiDnsProfile()
        }
    }

    onVisibleChanged: {
        if (!visible) {
            setDiscoveryForSection("")
            resetDetails()
        }
    }

    Component.onDestruction: setDiscoveryForSection("")

    Timer {
        id: detailMotionDone
        interval: Config.controlCenter.detailAnimation
        onTriggered: {
            if (!root.detailOpen)
                root.displayedSection = ""
            root.detailTransitionActive = false
        }
    }

    Behavior on detailProgress {
        NumberAnimation {
            duration: Config.controlCenter.detailAnimation
            easing.type: Animations.emphasizedEase
        }
    }

    Behavior on detailContentOpacity {
        NumberAnimation {
            duration: Animations.fast
            easing.type: Animations.standardEase
        }
    }

    SequentialAnimation {
        id: detailSwap
        NumberAnimation {
            target: root
            property: "detailContentOpacity"
            to: 0
            duration: Animations.fast
            easing.type: Animations.standardEase
        }
        ScriptAction {
            script: {
                root.displayedSection = root.pendingSection
                root.clearWifiCredentials()
                root.clearInformationView()
                root.expandedSection = root.pendingSection
                root.pendingSection = ""
            }
        }
        NumberAnimation {
            target: root
            property: "detailContentOpacity"
            to: 1
            duration: Animations.normal
            easing.type: Animations.emphasizedEase
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Control Center"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.detailOpen ? root.detailTitle() : "Focused system controls"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: NetworkService.statusLabel
                color: NetworkService.connected
                    ? Theme.success : Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
            }
        }

        Item {
            id: controlsBody
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.floor((parent.width - Theme.space2) * 0.52)
                spacing: Theme.space2

                LevelControl {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: AudioService.muted ? "Audio muted" : "Output volume"
                    detail: AudioService.outputName
                    icon: AudioService.muted ? "󰝟" : "󰕾"
                    level: AudioService.volume
                    available: AudioService.available
                    actionActive: AudioService.muted
                    expandable: AudioService.outputDevices.length > 0
                    expanded: root.expandedSection === "output"
                    onLevelRequested: level =>
                        AudioService.setVolume(Math.round(level * 100))
                    onActionRequested: AudioService.toggleMute()
                    onDetailsRequested: root.toggleSection("output")
                }

                LevelControl {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Display brightness"
                    detail: BrightnessService.deviceName
                    icon: "󰃟"
                    level: BrightnessService.level
                    available: BrightnessService.available
                    accent: Theme.tertiary
                    onLevelRequested: level =>
                        BrightnessService.setBrightness(Math.round(level * 100))
                }
            }

            GridLayout {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.floor((parent.width - Theme.space2) * 0.48)
                columns: 2
                rowSpacing: Theme.space2
                columnSpacing: Theme.space2

                ControlTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Wi-Fi"
                    detail: NetworkService.wifiConnected
                        ? NetworkService.ssid : NetworkService.wifiEnabled ? "On" : "Off"
                    icon: NetworkService.icon
                    checked: NetworkService.wifiEnabled
                    available: NetworkService.wifiAvailable
                    // Keep the icon action available while the radio is off:
                    // the same icon enables it again.  The detail affordance is
                    // tied to adapter presence, not its current enabled state.
                    expandable: NetworkService.wifiAvailable
                    expanded: root.expandedSection === "wifi"
                    onActivated: root.toggleSection("wifi")
                    onToggleRequested: NetworkService.toggleWifi()
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Bluetooth"
                    detail: BluetoothService.detailLabel
                    icon: BluetoothService.icon
                    checked: BluetoothService.enabled
                    available: BluetoothService.available && !BluetoothService.blocked
                    accent: Theme.tertiary
                    // Keep the icon action available while Bluetooth is off:
                    // the same icon enables it again. The detail affordance is
                    // tied to adapter availability, not its current enabled state.
                    expandable: BluetoothService.available && !BluetoothService.blocked
                    expanded: root.expandedSection === "bluetooth"
                    onActivated: root.toggleSection("bluetooth")
                    onToggleRequested: BluetoothService.toggleEnabled()
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Microphone"
                    detail: AudioService.microphoneMuted ? "Muted"
                        : AudioService.inputName
                    icon: AudioService.microphoneMuted ? "󰍭" : "󰍬"
                    checked: !AudioService.microphoneMuted
                    available: AudioService.microphoneAvailable
                    accent: AudioService.microphoneMuted ? Theme.error : Theme.primary
                    expandable: AudioService.inputDevices.length > 0
                    expanded: root.expandedSection === "input"
                    onActivated: root.toggleSection("input")
                    onToggleRequested: AudioService.toggleMicrophoneMute()
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Do not disturb"
                    detail: NotificationService.doNotDisturb ? "On" : "Off"
                    icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                    checked: NotificationService.doNotDisturb
                    accent: Theme.warning
                    onActivated: NotificationService.toggleDoNotDisturb()
                }
            }
        }

        Rectangle {
            id: detailPanel
            Layout.fillWidth: true
            Layout.preferredHeight: Config.controlCenter.detailHeight
                * root.detailProgress
            opacity: root.detailOpen ? 1 : 0
            clip: true
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainer, 0.80)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.52)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space1
                opacity: root.detailContentOpacity

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        visible: root.detailSubviewActive
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: detailBackHover.hovered
                            ? Theme.surfaceContainerHigh : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: Theme.surfaceVariantText
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: 18
                        }
                        HoverHandler { id: detailBackHover }
                        TapHandler { onTapped: root.closeDetailSubview() }
                    }
                    Text {
                        text: root.informationViewActive ? root.informationTitle()
                            : root.wifiCredentialsActive
                                ? (root.wifiCredentialNetwork?.name || "Wi-Fi password")
                                : root.detailTitle()
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        visible: root.informationViewActive
                            && root.displayedSection === "wifi"
                        spacing: Theme.space1

                        Repeater {
                            model: [
                                { label: "Automatic", automatic: true },
                                { label: "Manual", automatic: false }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 25
                                radius: Theme.radiusSmall
                                opacity: NetworkService.wifiProfileSaving ? 0.55 : 1
                                color: root.wifiAutomatic === modelData.automatic
                                    ? Theme.primaryContainer : "transparent"
                                border.width: 1
                                border.color: root.wifiAutomatic === modelData.automatic
                                    ? Qt.alpha(Theme.primary, 0.5)
                                    : Qt.alpha(Theme.outlineVariant, 0.44)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: root.wifiAutomatic === modelData.automatic
                                        ? Theme.primaryContainerText
                                        : Theme.surfaceVariantText
                                    font.family: Config.appearance.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }
                                TapHandler {
                                    enabled: !NetworkService.wifiProfileSaving
                                        && root.wifiAutomatic
                                            !== modelData.automatic
                                    onTapped: root.toggleWifiMode()
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: !root.detailSubviewActive
                            && (root.displayedSection === "wifi"
                                || root.displayedSection === "bluetooth")
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 24
                        radius: Theme.radiusSmall
                        color: scanHover.hovered ? Theme.surfaceContainerHigh
                            : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.space1
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.displayedSection === "wifi"
                                    ? (NetworkService.scanning ? "󰑓" : "󰖩")
                                    : (BluetoothService.discovering ? "󰑓" : "󰂯")
                                color: Theme.primary
                                font.family: Config.appearance.monoFontFamily
                                font.pixelSize: 10
                                RotationAnimation on rotation {
                                    running: !Config.appearance.reducedMotion
                                        && (root.displayedSection === "wifi"
                                            ? NetworkService.scanning
                                            : BluetoothService.discovering)
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1100
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.displayedSection === "wifi"
                                    ? NetworkService.scanning : BluetoothService.discovering)
                                        ? "Searching" : "Search"
                                color: Theme.surfaceVariantText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 8
                            }
                        }
                        HoverHandler { id: scanHover }
                        TapHandler { onTapped: root.toggleDiscovery() }
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }
                    Text {
                        visible: !root.detailSubviewActive
                        text: root.detailModel.length + (root.detailModel.length === 1 ? " option" : " options")
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 8
                    }
                }

                ListView {
                    id: detailList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Vertical
                    spacing: 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.detailModel

                    delegate: ConnectivityRow {
                        required property var modelData
                        width: detailList.width
                        height: 46
                        title: root.optionTitle(modelData)
                        detail: root.optionDetail(modelData)
                        icon: root.displayedSection === "wifi" ? "󰖩"
                            : root.displayedSection === "bluetooth"
                                ? BluetoothService.deviceIcon(modelData)
                            : root.displayedSection === "input" ? "󰍬" : "󰕾"
                        selected: root.optionSelected(modelData)
                        available: root.optionAvailable(modelData)
                        busy: modelData?.stateChanging || modelData?.pairing || false
                            || (root.displayedSection === "bluetooth"
                                && BluetoothService.deviceBusy(modelData))
                        accent: root.displayedSection === "bluetooth"
                            ? Theme.tertiary : Theme.primary
                        informationAvailable: (root.displayedSection === "wifi"
                            && modelData?.connected) || root.displayedSection === "bluetooth"
                        onActivated: root.activateOption(modelData)
                        onInformationRequested: root.showInformation(modelData)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: detailList.count === 0 && !root.detailSubviewActive
                        text: root.displayedSection === "bluetooth"
                            ? (BluetoothService.discovering
                                ? "Searching for nearby devices…" : "No devices found")
                            : (NetworkService.scanning
                                ? "Searching for networks…" : "No networks found")
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.wifiCredentialsActive
                        z: 3
                        radius: Theme.radiusSmall
                        color: Theme.surfaceContainer

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(470, parent.width - Theme.space5 * 2)
                            spacing: Theme.space2

                            Text {
                                Layout.fillWidth: true
                                text: "Enter the password for this network. It is passed directly to NetworkManager and is not stored by Odyssey."
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 9
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                spacing: Theme.space2

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusSmall
                                    color: Theme.surfaceContainerHigh
                                    border.width: wifiPasswordInput.activeFocus ? 1 : 0
                                    border.color: Qt.alpha(Theme.primary, 0.72)

                                    TextInput {
                                        id: wifiPasswordInput
                                        anchors.fill: parent
                                        anchors.margins: Theme.space2
                                        text: root.wifiPassword
                                        onTextChanged: root.wifiPassword = text
                                        color: Theme.surfaceText
                                        selectionColor: Theme.primary
                                        selectedTextColor: Theme.primaryText
                                        echoMode: TextInput.Password
                                        passwordCharacter: "•"
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Config.appearance.fontFamily
                                        font.pixelSize: 10
                                        Keys.onReturnPressed: root.submitWifiPassword()
                                        Keys.onEnterPressed: root.submitWifiPassword()
                                        Keys.onEscapePressed: root.clearWifiCredentials()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 88
                                    Layout.fillHeight: true
                                    radius: Theme.radiusSmall
                                    opacity: root.wifiPassword.length >= 8 ? 1 : 0.42
                                    color: Theme.primary
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: Theme.primaryText
                                        font.family: Config.appearance.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                    TapHandler {
                                        enabled: root.wifiPassword.length >= 8
                                        onTapped: root.submitWifiPassword()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.informationViewActive
                        z: 4
                        radius: Theme.radiusSmall
                        color: Theme.surfaceContainer

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.space2
                            visible: root.displayedSection === "wifi"
                            spacing: Theme.space2

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                spacing: Theme.space2

                                Repeater {
                                    model: [
                                        { label: "Connection", key: "status", value: root.informationOption?.connected ? "Connected" : "Disconnected", accent: Theme.success, editable: false },
                                        { label: "Signal", key: "signal", value: Math.round((root.informationOption?.signalStrength || 0) * 100) + "%", accent: Theme.primary, editable: false },
                                        { label: "IPv4 address", key: "address", value: NetworkService.wifiRuntime.address || "Not assigned", accent: Theme.primary, editable: true },
                                        { label: "Gateway", key: "gateway", value: NetworkService.wifiRuntime.gateway || "Not assigned", accent: Theme.tertiary, editable: true }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        radius: Theme.radiusSmall
                                        color: Qt.alpha(Theme.surfaceContainerHigh,
                                            Theme.dark ? 0.70 : 0.58)
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.outlineVariant, 0.34)

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: Theme.space2
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                                font.family: Config.appearance.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: root.wifiAutomatic
                                                    || !modelData.editable
                                                text: modelData.value
                                                color: modelData.accent
                                                elide: Text.ElideRight
                                                font.family: Config.appearance.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                            TextInput {
                                                Layout.fillWidth: true
                                                property bool userEdited: false
                                                visible: !root.wifiAutomatic
                                                    && modelData.editable
                                                text: modelData.key === "address"
                                                    ? root.manualWifiAddress
                                                    : root.manualWifiGateway
                                                color: root.validIpv4(text)
                                                    ? modelData.accent : Theme.error
                                                selectionColor: Theme.primary
                                                selectedTextColor: Theme.primaryText
                                                selectByMouse: true
                                                font.family: Config.appearance.monoFontFamily
                                                font.pixelSize: 10
                                                onTextEdited: {
                                                    userEdited = true
                                                    if (modelData.key === "address")
                                                        root.manualWifiAddress = text
                                                    else
                                                        root.manualWifiGateway = text
                                                    root.wifiModeStaged = true
                                                }
                                                onEditingFinished: {
                                                    if (!userEdited)
                                                        return
                                                    userEdited = false
                                                    root.saveManualWifiAddress()
                                                }
                                                Keys.onReturnPressed: {
                                                    userEdited = false
                                                    root.saveManualWifiAddress()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                radius: Theme.radiusSmall
                                color: Qt.alpha(Theme.surfaceContainerHigh,
                                    Theme.dark ? 0.52 : 0.42)
                                border.width: 1
                                border.color: Qt.alpha(Theme.outlineVariant, 0.34)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.space2
                                    spacing: Theme.space1

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 25
                                        spacing: 0

                                        Text {
                                            text: "DNS servers"
                                            color: Theme.surfaceText
                                            font.family: Config.appearance.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: root.wifiAutomatic
                                                ? "Provided by this network"
                                                : "Use a custom IPv4 resolver"
                                            color: Theme.surfaceVariantText
                                            font.family: Config.appearance.fontFamily
                                            font.pixelSize: 9
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 27
                                        visible: root.wifiAutomatic
                                        spacing: Theme.space1

                                        Repeater {
                                            model: root.automaticWifiDnsServers
                                                .split(",").map(value => value.trim())
                                                .filter(value => value.length > 0)
                                            delegate: Rectangle {
                                                required property string modelData
                                                width: Math.min(150,
                                                    automaticDnsLabel.implicitWidth
                                                        + Theme.space3 * 2)
                                                height: 27
                                                radius: Theme.radiusSmall
                                                color: Qt.alpha(Theme.surfaceContainer, 0.66)
                                                border.width: 1
                                                border.color: Qt.alpha(
                                                    Theme.outlineVariant, 0.32)

                                                Text {
                                                    id: automaticDnsLabel
                                                    anchors.centerIn: parent
                                                    width: Math.min(126, implicitWidth)
                                                    text: modelData
                                                    color: Theme.surfaceVariantText
                                                    elide: Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                    font.family: Config.appearance.monoFontFamily
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 27
                                        visible: !root.wifiAutomatic
                                        clip: true
                                        radius: Theme.radiusSmall
                                        color: Qt.alpha(Theme.surfaceContainer, 0.92)
                                        border.width: 1
                                        border.color: wifiDnsInput.activeFocus
                                            ? Qt.alpha(Theme.primary, 0.72)
                                            : Qt.alpha(Theme.outlineVariant, 0.32)

                                        TextInput {
                                            id: wifiDnsInput
                                            property bool userEdited: false
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.space2
                                            anchors.rightMargin: Theme.space2
                                            text: root.manualWifiDnsServers
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: Theme.surfaceText
                                            selectionColor: Theme.primary
                                            selectedTextColor: Theme.primaryText
                                            font.family: Config.appearance.monoFontFamily
                                            font.pixelSize: 10
                                            onTextEdited: {
                                                userEdited = true
                                                root.manualWifiDnsServers = text
                                            }
                                            onEditingFinished: {
                                                if (!userEdited)
                                                    return
                                                userEdited = false
                                                root.saveManualWifiDns()
                                            }
                                            Keys.onReturnPressed: {
                                                userEdited = false
                                                root.saveManualWifiDns()
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: NetworkService.wifiProfileError.length > 0 || NetworkService.wifiProfileStatus.length > 0
                                text: NetworkService.wifiProfileError || NetworkService.wifiProfileStatus
                                color: NetworkService.wifiProfileError.length > 0 ? Theme.error : Theme.success
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 8
                                wrapMode: Text.WordWrap
                            }
                        }

                        GridLayout {
                            anchors.centerIn: parent
                            width: Math.min(520, parent.width - Theme.space5 * 2)
                            columns: 2
                            rowSpacing: Theme.space3
                            columnSpacing: Theme.space5
                            visible: root.displayedSection !== "wifi"

                            Repeater {
                                model: root.informationRows()
                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: modelData.label.toUpperCase()
                                            color: Theme.surfaceVariantText
                                            font.family: Config.appearance.monoFontFamily
                                            font.pixelSize: 8
                                            font.letterSpacing: 1
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.value
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            font.family: Config.appearance.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: Qt.alpha(Theme.outlineVariant, 0.38)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Behavior on opacity { NumberAnimation { duration: Animations.normal } }
        }

        PowerProfileChooser {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
        }
    }
}
