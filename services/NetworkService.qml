pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    readonly property bool available: Networking.backend !== NetworkBackendType.None
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevices: devices.filter(device => device.type === DeviceType.Wifi)
    readonly property var ethernetDevices: devices.filter(device => device.type === DeviceType.Wired)
    readonly property var wifiDevice: wifiDevices.find(device => device.connected)
        || wifiDevices[0] || null
    readonly property var ethernetDevice: ethernetDevices.find(device => device.connected)
        || ethernetDevices[0] || null
    readonly property var wifiNetworks: wifiDevice?.networks?.values || []
    readonly property var activeWifiNetwork: wifiNetworks.find(network => network.connected) || null
    property var selectedWifiProfile: null
    property var wifiProfile: ({})
    property var wifiRuntime: ({})
    property string wifiProfileError: ""
    property string wifiProfileStatus: ""
    property bool wifiProfileSaving: false
    property bool runtimeQueryQueued: false

    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: available && Networking.wifiEnabled
    readonly property bool scanning: wifiAvailable && wifiDevice.scannerEnabled
    readonly property bool wifiConnected: activeWifiNetwork !== null
    readonly property bool ethernetConnected: ethernetDevice?.connected ?? false
    readonly property bool connected: wifiConnected || ethernetConnected
        || Networking.connectivity === NetworkConnectivity.Full
        || Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal

    readonly property string connectionType: ethernetConnected ? "ethernet"
        : (wifiConnected ? "wifi" : "none")
    readonly property string ssid: activeWifiNetwork?.name || ""
    readonly property int signalPercent: activeWifiNetwork
        ? Math.round(activeWifiNetwork.signalStrength * 100) : 0
    readonly property string connectionName: ethernetConnected
        ? (ethernetDevice.network?.name || "Ethernet")
        : (wifiConnected ? ssid : "Disconnected")
    readonly property string statusLabel: {
        if (!available)
            return "Unavailable"
        if (!connected)
            return wifiAvailable && !wifiEnabled ? "Wi-Fi disabled" : "Offline"
        if (limited)
            return connectionName + " · limited"
        return connectionName
    }
    readonly property string detailLabel: {
        if (wifiConnected)
            return signalPercent + "% signal"
        if (ethernetConnected)
            return ethernetDevice.name || "Wired connection"
        return available ? "No active connection" : "No network backend"
    }
    readonly property string icon: {
        if (ethernetConnected)
            return "󰈀"
        if (!wifiConnected)
            return "󰖪"
        if (signalPercent >= 67)
            return "󰖩"
        if (signalPercent >= 34)
            return "󰖩"
        return "󰤟"
    }

    function setWifiEnabled(value: bool): void {
        if (available && wifiAvailable)
            Networking.wifiEnabled = value
    }

    function toggleWifi(): void {
        setWifiEnabled(!wifiEnabled)
    }

    function setScanning(value: bool): void {
        if (!wifiAvailable)
            return
        const requested = value && wifiEnabled
        if (wifiDevice.scannerEnabled !== requested)
            wifiDevice.scannerEnabled = requested
    }

    function startScan(): void {
        setScanning(true)
    }

    function stopScan(): void {
        setScanning(false)
    }

    function securityLabel(network): string {
        if (!network)
            return "Unknown security"
        if (network.security === WifiSecurityType.Open)
            return "Open"
        if (network.security === WifiSecurityType.Sae)
            return "WPA3"
        if (network.security === WifiSecurityType.WpaPsk
                || network.security === WifiSecurityType.Wpa2Psk)
            return "WPA"
        if (network.security === WifiSecurityType.WpaEap
                || network.security === WifiSecurityType.Wpa2Eap)
            return "Enterprise"
        return WifiSecurityType.toString(network.security)
    }

    function supportsPassword(network): bool {
        if (!network)
            return false
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae
    }

    function requiresPassword(network): bool {
        return !!network && !network.connected && !network.known
            && supportsPassword(network)
    }

    function canSelectNetwork(network): bool {
        return !!network && !network.stateChanging && (network.connected
            || network.known || network.security === WifiSecurityType.Open
            || supportsPassword(network))
    }

    function selectWifiNetwork(network, password = ""): bool {
        if (!wifiEnabled || !network || network.stateChanging)
            return false
        if (network.connected)
            return true
        if (requiresPassword(network)) {
            if (!password)
                return false
            network.connectWithPsk(password)
            return true
        }
        if (!network.known && network.security !== WifiSecurityType.Open)
            return false
        network.connect()
        return true
    }

    function ipv4Number(value: string): real {
        const parts = value.trim().split(".")
        if (parts.length !== 4)
            return -1
        let result = 0
        for (let index = 0; index < parts.length; ++index) {
            if (!/^\d+$/.test(parts[index]))
                return -1
            const part = Number(parts[index])
            if (part < 0 || part > 255)
                return -1
            result += part * Math.pow(256, index)
        }
        return result
    }

    function ipv4String(value): string {
        const number = Number(value)
        if (!Number.isFinite(number))
            return ""
        return [0, 8, 16, 24].map(shift =>
            (number >>> shift) & 255).join(".")
    }

    function profileForNetwork(network) {
        const profiles = network?.nmSettings || []
        if (profiles.length === 0)
            return null
        return profiles.slice().sort((left, right) => {
            const leftConnection = left.read()?.connection || {}
            const rightConnection = right.read()?.connection || {}
            return Number(rightConnection.timestamp || 0) - Number(leftConnection.timestamp || 0)
                || String(leftConnection.id || "").localeCompare(String(rightConnection.id || ""))
        })[0]
    }

    function refreshActiveWifiProfile(): void {
        if (!selectedWifiProfile)
            return
        const settings = selectedWifiProfile.read()
        const ipv4 = settings?.ipv4 || {}
        const address = Array.isArray(ipv4["address-data"]) ? ipv4["address-data"][0] || {} : {}
        const dns = Array.isArray(ipv4.dns) ? ipv4.dns.map(ipv4String).filter(Boolean) : []
        wifiProfile = {
            address: String(address.address || "Unavailable"),
            gateway: String(ipv4.gateway || "Unavailable"),
            automaticAddress: String(ipv4.method || "auto") !== "manual",
            automaticDns: !ipv4["ignore-auto-dns"],
            // NetworkManager retains these profile servers while automatic DNS
            // is enabled, but ignores them until Manual is selected again.
            // Keeping the two roles explicit prevents mode changes from
            // discarding a user's previous manual DNS entry.
            automaticDnsServers: dns.join(", "),
            manualDnsServers: dns.join(", ")
        }
        refreshActiveWifiRuntime()
    }

    function refreshActiveWifiRuntime(): void {
        if (!wifiDevice || !wifiDevice.connected || !wifiDevice.name) {
            wifiRuntime = ({})
            return
        }
        if (runtimeQuery.running) {
            runtimeQueryQueued = true
            return
        }
        runtimeQuery.command = ["nmcli", "-t", "-f",
            "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show",
            wifiDevice.name]
        runtimeQuery.running = true
    }

    function parseActiveWifiRuntime(output: string): void {
        let address = ""
        let prefix = -1
        let gateway = ""
        const dns = []
        output.split("\n").forEach(line => {
            const separator = line.indexOf(":")
            if (separator < 0)
                return
            const key = line.slice(0, separator)
            const value = line.slice(separator + 1).trim()
            if (key.indexOf("IP4.ADDRESS") === 0 && !address) {
                const addressParts = value.split("/")
                address = addressParts[0]
                if (addressParts.length === 2)
                    prefix = Number(addressParts[1])
            }
            else if (key === "IP4.GATEWAY")
                gateway = value
            else if (key.indexOf("IP4.DNS") === 0 && value)
                dns.push(value)
        })
        wifiRuntime = {
            address: address,
            prefix: prefix,
            gateway: gateway,
            dnsServers: dns.join(", ")
        }
    }

    function openActiveWifiProfile(network): bool {
        selectedWifiProfile = null
        wifiProfile = ({})
        wifiRuntime = ({})
        runtimeQueryQueued = false
        wifiProfileError = ""
        wifiProfileStatus = ""
        if (!network || !network.connected) {
            wifiProfileError = "Only the active Wi-Fi connection can be edited."
            return false
        }
        selectedWifiProfile = profileForNetwork(network)
        if (!selectedWifiProfile) {
            wifiProfileError = "No saved NetworkManager profile is available."
            return false
        }
        refreshActiveWifiProfile()
        return true
    }

    function closeActiveWifiProfile(): void {
        selectedWifiProfile = null
        wifiProfile = ({})
        wifiRuntime = ({})
        wifiProfileError = ""
        wifiProfileStatus = ""
        wifiProfileSaving = false
    }

    function applyActiveWifiDns(automatic: bool, dnsText: string): bool {
        if (!selectedWifiProfile || wifiProfileSaving)
            return false
        const servers = dnsText.split(/[\s,]+/).filter(Boolean)
        const numbers = servers.map(ipv4Number)
        if (!automatic && (numbers.length === 0 || numbers.some(value => value < 0))) {
            wifiProfileError = "Enter one or more valid IPv4 DNS servers."
            wifiProfileStatus = ""
            return false
        }
        wifiProfileSaving = true
        wifiProfileError = ""
        wifiProfileStatus = "Saving with NetworkManager…"
        // NMSettings merges this bounded IPv4 DNS patch with the active saved
        // profile. No resolver, route, IPv6, or connection settings are touched.
        const ipv4Patch = { "ignore-auto-dns": !automatic }
        // Do not clear ipv4.dns when returning to automatic. NetworkManager
        // ignores it in that mode and retains it in the saved Wi-Fi profile
        // for the next return to manual DNS.
        if (!automatic)
            ipv4Patch.dns = numbers
        selectedWifiProfile.write({ ipv4: ipv4Patch })
        profileRefresh.restart()
        return true
    }

    function applyActiveWifiAddress(addressText: string,
            gatewayText: string): bool {
        if (!selectedWifiProfile || wifiProfileSaving)
            return false
        const address = addressText.trim()
        const gateway = gatewayText.trim()
        if (ipv4Number(address) < 0 || ipv4Number(gateway) < 0) {
            wifiProfileError = "Enter a valid IPv4 address and gateway."
            wifiProfileStatus = ""
            return false
        }
        const prefix = Number(wifiRuntime.prefix)
        if (!Number.isInteger(prefix) || prefix < 1 || prefix > 32) {
            wifiProfileError = "The active subnet prefix is unavailable."
            wifiProfileStatus = ""
            return false
        }
        wifiProfileSaving = true
        wifiProfileError = ""
        wifiProfileStatus = "Saving with NetworkManager…"
        selectedWifiProfile.write({ ipv4: {
            method: "manual",
            "address-data": [{ address: address, prefix: prefix }],
            gateway: gateway
        } })
        profileRefresh.restart()
        return true
    }

    function applyActiveWifiAutomatic(): bool {
        if (!selectedWifiProfile || wifiProfileSaving)
            return false
        wifiProfileSaving = true
        wifiProfileError = ""
        wifiProfileStatus = "Saving with NetworkManager…"
        selectedWifiProfile.write({ ipv4: {
            method: "auto",
            "ignore-auto-dns": false
        } })
        profileRefresh.restart()
        return true
    }

    property string runtimeQueryOutput: ""
    property Process runtimeQuery: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.runtimeQueryOutput = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (!root.selectedWifiProfile)
                root.wifiRuntime = ({})
            else if (exitCode === 0)
                root.parseActiveWifiRuntime(root.runtimeQueryOutput)
            else
                root.wifiRuntime = ({})
            if (root.runtimeQueryQueued && root.selectedWifiProfile) {
                root.runtimeQueryQueued = false
                Qt.callLater(() => root.refreshActiveWifiRuntime())
            }
        }
    }

    property Timer profileRefresh: Timer {
        interval: 400
        repeat: false
        onTriggered: {
            if (root.wifiProfileSaving) {
                root.wifiProfileSaving = false
                root.wifiProfileStatus = ""
                root.wifiProfileError = "NetworkManager did not confirm the network update."
            }
        }
    }

    property Connections profileConnections: Connections {
        target: root.selectedWifiProfile
        function onSettingsChanged(settings) {
            root.refreshActiveWifiProfile()
            root.wifiProfileSaving = false
            root.wifiProfileError = ""
            root.wifiProfileStatus = "Saved by NetworkManager."
        }
        function onLoaded() { root.refreshActiveWifiProfile() }
    }
}
