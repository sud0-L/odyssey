pragma Singleton
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool changing: available && (adapter.state === BluetoothAdapterState.Enabling
        || adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool discovering: available && adapter.discovering

    property var operationDevice: null
    property string operationAddress: ""
    property string operationName: ""
    property string operationPhase: ""
    property bool sawPairing: false
    property bool sawConnecting: false
    property bool discoveryRequested: false
    property bool pairAfterDisconnect: false
    property var errorsByAddress: ({})
    property var knownConnectedAddresses: ({})
    property string pairProcessOutput: ""
    property int pairCompletionAttempts: 0
    property bool pairingAgentReady: false
    property bool rawPairStarted: false

    readonly property var devices: available ? adapter.devices.values : []
    readonly property var pairedDevices: devices.filter(device => device.paired || device.bonded)
    readonly property var discoverableDevices: {
        const result = devices.filter(device => device && !device.blocked
            && deviceName(device).length > 0)
        result.sort((a, b) => Number(b.connected) - Number(a.connected)
            || Number(b.paired || b.bonded) - Number(a.paired || a.bonded)
            || deviceName(a).localeCompare(deviceName(b)))
        return result
    }
    readonly property var connectedDevices: devices.filter(device => deviceReady(device))
    readonly property int connectedCount: connectedDevices.length
    readonly property bool connected: connectedCount > 0
    readonly property var primaryDevice: connectedDevices[0] || null

    readonly property string primaryDeviceName: deviceName(primaryDevice)
    readonly property int primaryDeviceBattery: primaryDevice?.batteryAvailable
        ? Math.round(primaryDevice.battery * 100) : -1
    readonly property string statusLabel: {
        if (!available)
            return "Unavailable"
        if (blocked)
            return "Blocked"
        if (changing)
            return BluetoothAdapterState.toString(adapter.state)
        if (!enabled)
            return "Off"
        if (connectedCount === 1)
            return "1 connected"
        if (connectedCount > 1)
            return connectedCount + " connected"
        return "On"
    }
    readonly property string detailLabel: {
        if (!available)
            return "No adapter"
        if (connected) {
            const batteryLabel = primaryDeviceBattery >= 0
                ? " · " + primaryDeviceBattery + "%" : ""
            return primaryDeviceName + batteryLabel
        }
        if (!enabled)
            return blocked ? "Radio blocked" : "Adapter disabled"
        return pairedDevices.length > 0
            ? pairedDevices.length + " paired" : (adapter.name || "Ready")
    }
    readonly property string icon: !enabled ? "󰂲" : (connected ? "󰂱" : "󰂯")

    Component.onCompleted: Qt.callLater(() => syncConnectedDevices(false))

    onConnectedDevicesChanged: Qt.callLater(() => syncConnectedDevices(false))

    function deviceName(device): string {
        return device?.name || device?.deviceName || "Bluetooth device"
    }

    function deviceAddress(device): string {
        return String(device?.address || "").toLowerCase()
    }

    function deviceForAddress(address: string): var {
        const identity = String(address || "").toLowerCase()
        return devices.find(device => deviceAddress(device) === identity) || null
    }

    function isAudioDevice(device): bool {
        const iconName = String(device?.icon || "").toLowerCase()
        const name = deviceName(device).toLowerCase()
        return iconName.includes("audio") || iconName.includes("head")
            || name.includes("airpod")
    }

    function deviceReady(device): bool {
        return !!device && device.connected && (device.paired || device.bonded)
    }

    function setEnabled(value): void {
        if (available && !blocked)
            adapter.enabled = value
    }

    function toggleEnabled(): void {
        setEnabled(!enabled)
    }

    function setDiscovering(value: bool): void {
        discoveryRequested = value
        if (!available)
            return
        const requested = value && enabled
        if (adapter.discovering !== requested)
            adapter.discovering = requested
    }

    function restoreDiscovery(): void {
        if (discoveryRequested)
            Qt.callLater(() => root.setDiscovering(true))
    }

    function startDiscovery(): void {
        setDiscovering(true)
    }

    function stopDiscovery(): void {
        setDiscovering(false)
    }

    function deviceBusy(device): bool {
        return !!device && (operationDevice === device || device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting)
    }

    function canActivateDevice(device): bool {
        return enabled && !!device && !device.blocked
            && (!operationDevice || operationDevice === device)
            && !deviceBusy(device)
    }

    function deviceError(device): string {
        return errorsByAddress[deviceAddress(device)] || ""
    }

    function deviceStatusLabel(device): string {
        if (!device)
            return "Unavailable"
        if (operationDevice === device) {
            if (operationPhase === "pairing")
                return "Pairing…"
            if (operationPhase === "resetting")
                return "Pairing…"
            if (operationPhase === "trusting")
                return "Trusting…"
            if (operationPhase === "connecting")
                return "Connecting…"
            if (operationPhase === "disconnecting")
                return "Disconnecting…"
        }
        if (device.pairing)
            return "Pairing…"
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…"
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…"
        const failure = deviceError(device)
        if (failure)
            return failure
        if (deviceReady(device))
            return "Connected · Disconnect"
        if (device.connected)
            return "Pairing incomplete · Retry"
        return device.paired || device.bonded ? "Connect" : "Pair"
    }

    function setDeviceError(device, message: string): void {
        setAddressError(deviceAddress(device), message)
    }

    function setAddressError(address: string, message: string): void {
        if (!address)
            return
        if ((!message && !errorsByAddress[address])
                || errorsByAddress[address] === message)
            return
        const updated = Object.assign({}, errorsByAddress)
        if (message)
            updated[address] = message
        else
            delete updated[address]
        errorsByAddress = updated
    }

    function deviceIcon(device): string {
        const identity = ((device?.icon || "") + " " + deviceName(device)).toLowerCase()
        if (identity.includes("head") || identity.includes("audio")
                || identity.includes("airpod"))
            return "󰋋"
        if (identity.includes("mouse"))
            return "󰍽"
        if (identity.includes("keyboard"))
            return "󰌌"
        if (identity.includes("phone"))
            return "󰄜"
        return "󰂯"
    }

    function startPhase(device, phase: string, timeout: int): void {
        operationDevice = device
        operationAddress = deviceAddress(device) || operationAddress
        operationName = deviceName(device) || operationName
        operationPhase = phase
        operationTimeout.interval = timeout
        operationTimeout.restart()
        phaseSettle.restart()
    }

    function clearOperation(): void {
        operationTimeout.stop()
        phaseSettle.stop()
        bredrScanDelay.stop()
        pairCompletion.stop()
        pairStartCheck.stop()
        closePairingAgent()
        operationDevice = null
        operationAddress = ""
        operationName = ""
        operationPhase = ""
        sawPairing = false
        sawConnecting = false
        pairAfterDisconnect = false
        pairingAgentReady = false
        rawPairStarted = false
        restoreDiscovery()
    }

    function failOperation(message: string): void {
        const device = operationDevice
        if (device)
            setDeviceError(device, message)
        else if (operationAddress)
            setAddressError(operationAddress, message)
        clearOperation()
    }

    function finishConnected(): void {
        const device = operationDevice
        if (!device || !device.connected)
            return
        setDeviceError(device, "")
        const address = deviceAddress(device)
        const audio = isAudioDevice(device)
        clearOperation()
        syncConnectedDevices(false)
        if (audio)
            AudioService.requestBluetoothOutput(address, deviceName(device), true)
    }

    function beginPair(device): void {
        sawPairing = !!device.pairing
        pairProcessOutput = ""
        pairCompletionAttempts = 0
        pairingAgentReady = false
        rawPairStarted = false
        startPhase(device, "pairing", 45000)
        // BlueZ 5.87 can race cross-transport authentication for dual-mode
        // Apple devices. Stop the interleaved scan, rediscover over Classic,
        // then use BlueZ's agent-capable client for pairing.
        if (available && adapter.discovering)
            adapter.discovering = false
        bredrScanDelay.restart()
        phaseSettle.stop()
    }

    function launchPairProcess(): void {
        if (operationPhase !== "pairing" || !operationAddress)
            return
        // Keep bluetoothctl alive only as a BlueZ agent. The high-level
        // `bluetoothctl pair` command also performs its own trust/connect
        // sequence, which can tear down an otherwise successful audio bond.
        // Quickshell's pair() maps directly to org.bluez.Device1.Pair().
        pairProcess.command = ["bluetoothctl", "--agent", "NoInputNoOutput"]
        pairProcess.running = true
    }

    function recordPairProcessLine(line: string): void {
        pairProcessOutput += (pairProcessOutput ? "\n" : "") + line
        if (line.toLowerCase().includes("agent registered")) {
            pairingAgentReady = true
            Qt.callLater(() => root.beginRawPair())
        }
    }

    function beginRawPair(): void {
        if (operationPhase !== "pairing" || !pairingAgentReady
                || rawPairStarted)
            return
        const device = deviceForAddress(operationAddress) || operationDevice
        if (!device) {
            failOperation("Device unavailable · Retry")
            return
        }
        operationDevice = device
        rawPairStarted = true
        sawPairing = !!device.pairing
        device.pair()
        pairStartCheck.restart()
    }

    function closePairingAgent(): void {
        if (!pairProcess.running)
            return
        pairProcess.write("quit\n")
        pairProcess.running = false
    }

    function continueAfterPair(): void {
        const device = operationDevice
        if (!device || !(device.paired || device.bonded)
                || (operationPhase && operationPhase !== "pairing"))
            return
        closePairingAgent()
        if (device.trusted) {
            beginConnect()
            return
        }
        startPhase(device, "trusting", 5000)
        device.trusted = true
        if (device.trusted)
            Qt.callLater(() => root.beginConnect())
    }

    function beginConnect(): void {
        const device = operationDevice
        if (!device)
            return
        if (operationPhase === "connecting")
            return
        if (device.connected) {
            // Pair() may leave only BlueZ's base transport/service discovery
            // connected. Still ask Device1.Connect() to connect all supported
            // profiles so WirePlumber receives the A2DP transport.
            device.connect()
            finishConnected()
            return
        }
        sawConnecting = device.state === BluetoothDeviceState.Connecting
        startPhase(device, "connecting", 15000)
        device.connect()
    }

    function beginDisconnect(device): void {
        startPhase(device, "disconnecting", 10000)
        AudioService.cancelBluetoothOutputRequest(deviceAddress(device))
        device.disconnect()
        if (!device.connected)
            Qt.callLater(() => root.clearOperation())
    }

    function resetIncompleteConnection(device): void {
        pairAfterDisconnect = true
        startPhase(device, "resetting", 10000)
        device.disconnect()
        if (!device.connected) {
            pairAfterDisconnect = false
            Qt.callLater(() => root.beginPair(device))
        }
    }

    function activateDevice(device): bool {
        if (!canActivateDevice(device))
            return false
        setDeviceError(device, "")
        if (deviceReady(device))
            beginDisconnect(device)
        else if (device.connected)
            resetIncompleteConnection(device)
        else if (device.paired || device.bonded) {
            operationDevice = device
            continueAfterPair()
        } else {
            beginPair(device)
        }
        return true
    }

    function forgetDevice(device): bool {
        if (!enabled || !device || device.blocked || deviceBusy(device))
            return false
        const address = deviceAddress(device)
        AudioService.cancelBluetoothOutputRequest(address)
        setDeviceError(device, "")
        device.forget()
        restoreDiscovery()
        return true
    }

    function syncConnectedDevices(autoSelect: bool): void {
        const next = ({})
        for (const device of connectedDevices) {
            const address = deviceAddress(device)
            if (!address)
                continue
            next[address] = true
            setDeviceError(device, "")
            if (!knownConnectedAddresses[address] && isAudioDevice(device))
                AudioService.requestBluetoothOutput(address,
                    deviceName(device), autoSelect)
        }
        for (const address of Object.keys(knownConnectedAddresses)) {
            if (!next[address])
                AudioService.cancelBluetoothOutputRequest(address)
        }
        knownConnectedAddresses = next
    }

    property Connections operationEvents: Connections {
        target: root.operationDevice

        function onPairingChanged(): void {
            const device = root.operationDevice
            if (!device || root.operationPhase !== "pairing")
                return
            if (device.pairing)
                root.sawPairing = true
            else if (device.paired || device.bonded)
                Qt.callLater(() => root.continueAfterPair())
            else if (root.sawPairing)
                root.pairCompletion.restart()
        }

        function onPairedChanged(): void {
            if (root.operationPhase === "pairing"
                    && (root.operationDevice?.paired
                        || root.operationDevice?.bonded))
                Qt.callLater(() => root.continueAfterPair())
        }

        function onBondedChanged(): void {
            if (root.operationPhase === "pairing"
                    && (root.operationDevice?.paired
                        || root.operationDevice?.bonded))
                Qt.callLater(() => root.continueAfterPair())
        }

        function onTrustedChanged(): void {
            if (root.operationPhase === "trusting"
                    && root.operationDevice?.trusted)
                Qt.callLater(() => root.beginConnect())
        }

        function onStateChanged(): void {
            const device = root.operationDevice
            if (!device)
                return
            if (root.operationPhase === "connecting") {
                if (device.connected) {
                    root.finishConnected()
                } else if (device.state === BluetoothDeviceState.Connecting) {
                    root.sawConnecting = true
                } else if (root.sawConnecting
                        && device.state === BluetoothDeviceState.Disconnected) {
                    root.failOperation("Connection failed · Retry")
                }
            } else if (root.operationPhase === "disconnecting"
                    && !device.connected) {
                root.clearOperation()
            } else if (root.operationPhase === "resetting"
                    && !device.connected && root.pairAfterDisconnect) {
                root.pairAfterDisconnect = false
                root.beginPair(device)
            }
        }

        function onConnectedChanged(): void {
            const device = root.operationDevice
            if (!device)
                return
            if (root.operationPhase === "connecting" && device.connected)
                root.finishConnected()
            else if (root.operationPhase === "disconnecting"
                    && !device.connected)
                root.clearOperation()
            else if (root.operationPhase === "resetting"
                    && !device.connected && root.pairAfterDisconnect) {
                root.pairAfterDisconnect = false
                root.beginPair(device)
            }
        }
    }

    property Process pairProcess: Process {
        running: false
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.recordPairProcessLine(line)
        }
        stderr: SplitParser {
            onRead: line => root.recordPairProcessLine(line)
        }
        onExited: (exitCode, exitStatus) => {
            if (root.operationPhase !== "pairing")
                return
            if (root.operationDevice?.paired || root.operationDevice?.bonded)
                Qt.callLater(() => root.continueAfterPair())
            else if (!root.rawPairStarted)
                root.failOperation("Pairing agent unavailable · Retry")
            else
                pairCompletion.restart()
        }
    }

    property Timer bredrScanDelay: Timer {
        interval: 650
        onTriggered: {
            if (root.operationPhase !== "pairing")
                return
            bredrScanProcess.command = ["bluetoothctl", "--timeout", "4",
                "scan", "bredr"]
            bredrScanProcess.running = true
        }
    }

    property Process bredrScanProcess: Process {
        running: false
        onExited: (exitCode, exitStatus) => root.launchPairProcess()
    }

    property Timer pairStartCheck: Timer {
        interval: 1800
        onTriggered: {
            if (root.operationPhase !== "pairing")
                return
            const device = root.deviceForAddress(root.operationAddress)
                || root.operationDevice
            if (device && (device.paired || device.bonded)) {
                root.continueAfterPair()
                return
            }
            if (!device?.pairing && !root.sawPairing)
                root.pairCompletion.restart()
        }
    }

    property Timer pairCompletion: Timer {
        interval: 400
        onTriggered: {
            if (root.operationPhase !== "pairing")
                return
            const device = root.deviceForAddress(root.operationAddress)
                || root.operationDevice
            if (device)
                root.operationDevice = device
            if (!device && root.pairCompletionAttempts < 5) {
                root.pairCompletionAttempts += 1
                pairCompletion.restart()
                return
            }
            if (device && (device.paired || device.bonded)) {
                root.continueAfterPair()
                return
            }
            if (device?.pairing)
                return
            if (device?.connected)
                device.disconnect()
            const output = root.pairProcessOutput.toLowerCase()
            console.warn("Odyssey Bluetooth pairing failed:",
                root.pairProcessOutput || "No diagnostic output")
            if (output.includes("pairing successful"))
                root.failOperation("BlueZ removed audio bond · Retry")
            else if (output.includes("agent registration failed")
                    || output.includes("no agent is registered"))
                root.failOperation("Pairing agent unavailable · Retry")
            else if (output.includes("authenticationrejected")
                    || output.includes("authentication rejected"))
                root.failOperation("Device rejected pairing · Retry")
            else if (output.includes("authenticationcanceled")
                    || output.includes("authentication canceled"))
                root.failOperation("Pairing canceled · Retry")
            else if (output.includes("connectionattemptfailed")
                    || output.includes("page timeout"))
                root.failOperation("Device unavailable · Retry")
            else
                root.failOperation("Pairing failed · Retry")
        }
    }

    property Timer phaseSettle: Timer {
        interval: 1400
        onTriggered: {
            const device = root.operationDevice
            if (!device)
                return
            if (root.operationPhase === "pairing" && !device.pairing
                    && !(device.paired || device.bonded))
                root.failOperation("Pairing failed · Retry")
            else if (root.operationPhase === "trusting" && !device.trusted)
                root.failOperation("Trust failed · Retry")
            else if (root.operationPhase === "connecting" && !device.connected
                    && device.state !== BluetoothDeviceState.Connecting)
                root.failOperation("Connection failed · Retry")
        }
    }

    property Timer operationTimeout: Timer {
        onTriggered: {
            const device = root.operationDevice
            if (!device)
                return
            if (root.operationPhase === "pairing"
                    && (root.pairProcess.running
                        || root.bredrScanProcess.running)) {
                root.failOperation("Pairing timed out · Retry")
                root.bredrScanProcess.running = false
                return
            }
            if (root.operationPhase === "pairing" && device.pairing)
                device.cancelPair()
            root.failOperation(root.operationPhase === "pairing"
                ? "Pairing timed out · Retry"
                : root.operationPhase === "trusting"
                    ? "Trust timed out · Retry"
                    : root.operationPhase === "disconnecting"
                        ? "Disconnect timed out · Retry"
                        : root.operationPhase === "resetting"
                            ? "Pairing reset failed · Retry"
                        : "Connection timed out · Retry")
        }
    }
}
