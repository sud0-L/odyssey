pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../core"

QtObject {
    id: root

    readonly property var batteries: UPower.devices.values.filter(device =>
        device?.ready && device.isLaptopBattery && device.isPresent)
    readonly property var device: batteries[0] || null

    readonly property bool available: batteries.length > 0
    readonly property bool charging: available && batteries.some(device =>
        device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool discharging: available && batteries.some(device =>
        device.state === UPowerDeviceState.Discharging
            || device.state === UPowerDeviceState.PendingDischarge)
    // Some firmware exposes an always-online USB-C source to UPower. Prefer
    // the battery's actual discharge state so source and runtime remain
    // correct on those systems, while retaining UPower as a fallback.
    readonly property bool onBattery: available && (discharging
        || (!charging && UPower.onBattery))
    readonly property bool fullyCharged: available && batteries.every(device =>
        device.state === UPowerDeviceState.FullyCharged)

    readonly property real energy: available
        ? batteries.reduce((total, battery) => total + Math.max(0, battery.energy), 0) : 0
    readonly property real energyCapacity: available
        ? batteries.reduce((total, battery) => total + Math.max(0, battery.energyCapacity), 0) : 0
    readonly property real percentage: {
        if (!available)
            return 0
        if (energyCapacity > 0)
            return Math.max(0, Math.min(1, energy / energyCapacity))
        return batteries.reduce((total, battery) => total + battery.percentage, 0)
            / batteries.length
    }
    readonly property int percentageInt: Math.round(percentage * 100)

    readonly property bool healthAvailable: available && batteries.some(battery =>
        battery.healthSupported && battery.healthPercentage > 0)
    readonly property real healthPercentage: {
        const healthyBatteries = batteries.filter(battery =>
            battery.healthSupported && battery.healthPercentage > 0)
        if (healthyBatteries.length === 0)
            return 0
        return healthyBatteries.reduce((total, battery) =>
            total + battery.healthPercentage, 0) / healthyBatteries.length
    }
    readonly property int healthPercentageInt: Math.round(healthPercentage)
    readonly property string healthLabel: !healthAvailable ? "Unavailable"
        : healthPercentageInt >= 90 ? "Excellent"
        : healthPercentageInt >= 80 ? "Good"
        : healthPercentageInt >= 65 ? "Reduced" : "Service recommended"

    readonly property real chargeRate: available
        ? batteries.reduce((total, battery) =>
            total + Math.max(0, battery.changeRate), 0) : 0
    readonly property string chargeRateLabel: chargeRate > 0
        ? chargeRate.toFixed(1) + " W" : "Unavailable"
    readonly property string capacityLabel: energyCapacity > 0
        ? energyCapacity.toFixed(1) + " Wh" : "Unavailable"
    readonly property string modelLabel: device?.model || "Laptop battery"

    readonly property real timeRemaining: {
        if (!device)
            return 0
        return charging ? device.timeToFull : (onBattery ? device.timeToEmpty : 0)
    }
    readonly property real timeToFull: device ? device.timeToFull : 0
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property string chargeTimeLabel: charging
        ? (formatDuration(timeToFull) || "Calculating") : "Not charging"
    readonly property string emptyTimeLabel: onBattery
        ? (formatDuration(timeToEmpty) || "Calculating") : "On AC power"
    readonly property string timeLabel: formatDuration(timeRemaining)
    readonly property string statusLabel: {
        if (!available)
            return "Unavailable"
        if (fullyCharged)
            return "Fully charged"
        if (charging)
            return timeLabel ? "Charging · " + timeLabel : "Charging"
        if (onBattery)
            return timeLabel ? timeLabel + " remaining" : "On battery"
        return "Plugged in"
    }
    readonly property string sourceLabel: onBattery ? "Battery" : "AC power"
    property bool eventsEnabled: false
    property bool powerStateInitialized: false
    property bool previousOnBattery: false

    signal powerConnected()
    signal powerDisconnected()
    readonly property string icon: {
        if (charging)
            return "󰂄"
        if (percentageInt <= 10)
            return "󰁺"
        if (percentageInt <= 25)
            return "󰁻"
        if (percentageInt <= 50)
            return "󰁾"
        if (percentageInt <= 75)
            return "󰂀"
        if (percentageInt < 95)
            return "󰂂"
        return "󰁹"
    }

    function formatDuration(seconds): string {
        if (!Number.isFinite(seconds) || seconds <= 0 || seconds > 172800)
            return ""
        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const remainder = minutes % 60
        return hours > 0 ? hours + "h " + remainder + "m" : minutes + "m"
    }

    function syncPowerState(): void {
        if (!available) {
            powerStateInitialized = false
            return
        }
        if (!eventsEnabled || !powerStateInitialized) {
            previousOnBattery = onBattery
            powerStateInitialized = true
            return
        }
        if (previousOnBattery === onBattery)
            return
        previousOnBattery = onBattery
        console.info("Odyssey power source:", onBattery
            ? "battery" : "external power")
        if (Config.idle.powerSoundsEnabled) {
            Quickshell.execDetached([Quickshell.shellDir
                + "/scripts/power-sound.sh",
                onBattery ? "disconnected" : "connected"])
        }
        if (onBattery)
            powerDisconnected()
        else
            powerConnected()
    }

    onOnBatteryChanged: syncPowerState()
    onAvailableChanged: syncPowerState()

    // Track the battery device directly. On some Zephyrus firmware the
    // aggregate UPower.onBattery flag is held false by a stale UCSI source,
    // while the battery's state still changes correctly for both barrel AC
    // and USB-C Power Delivery.
    property Connections batteryStateEvents: Connections {
        target: root.device
        function onStateChanged(): void {
            Qt.callLater(root.syncPowerState)
        }
        function onReadyChanged(): void {
            Qt.callLater(root.syncPowerState)
        }
    }

    property Connections aggregatePowerEvents: Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            Qt.callLater(root.syncPowerState)
        }
    }

    property Timer startupGuard: Timer {
        interval: 900
        running: true
        onTriggered: {
            root.eventsEnabled = true
            root.syncPowerState()
        }
    }
}
