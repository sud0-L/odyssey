pragma Singleton
import QtQuick
import Quickshell.Bluetooth

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool changing: available && (adapter.state === BluetoothAdapterState.Enabling
        || adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool discovering: available && adapter.discovering

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
    readonly property var connectedDevices: devices.filter(device => device.connected)
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

    function deviceName(device): string {
        return device?.name || device?.deviceName || "Bluetooth device"
    }

    function setEnabled(value): void {
        if (available && !blocked)
            adapter.enabled = value
    }

    function toggleEnabled(): void {
        setEnabled(!enabled)
    }

    function setDiscovering(value: bool): void {
        if (!available)
            return
        const requested = value && enabled
        if (adapter.discovering !== requested)
            adapter.discovering = requested
    }

    function startDiscovery(): void {
        setDiscovering(true)
    }

    function stopDiscovery(): void {
        setDiscovering(false)
    }

    function deviceBusy(device): bool {
        return !!device && (device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting)
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

    function toggleDeviceConnection(device): bool {
        if (!enabled || !device || !(device.paired || device.bonded)
                || device.blocked || device.pairing)
            return false
        if (device.connected)
            device.disconnect()
        else {
            device.trusted = true
            device.connect()
        }
        return true
    }

    function activateDevice(device): bool {
        if (!enabled || !device || device.blocked || deviceBusy(device))
            return false
        if (device.paired || device.bonded)
            return toggleDeviceConnection(device)
        // Native Quickshell can initiate Just Works pairing. Devices requiring
        // PIN/passkey authorization need Odyssey's future BlueZ agent surface.
        device.pair()
        return true
    }
}
