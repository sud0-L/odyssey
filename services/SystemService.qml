pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property real cpuUsage: 0
    property real memoryUsage: 0
    property real temperature: 0
    property real gpuTemperature: 0
    property real gpuUsage: 0
    property real diskUsage: 0
    property real memoryTotalBytes: 0
    property real memoryUsedBytes: 0
    property real diskTotalBytes: 0
    property real diskUsedBytes: 0
    property real uptimeSeconds: 0
    property bool temperatureAvailable: false
    property bool storageAvailable: false
    property bool gpuAvailable: false
    property bool gpuTemperatureAvailable: false
    property bool gpuUsageAvailable: false
    property string cpuTemperaturePath: Config.system.temperaturePath
    property string gpuTemperaturePath: ""
    property string gpuLoadPath: ""
    property string cpuModel: "Processor unavailable"
    property string gpuModel: "Graphics unavailable"
    property string osName: "Linux"
    property real previousCpuTotal: 0
    property real previousCpuIdle: 0

    readonly property int cpuPercent: Math.round(cpuUsage * 100)
    readonly property int memoryPercent: Math.round(memoryUsage * 100)
    readonly property int diskPercent: Math.round(diskUsage * 100)
    readonly property int temperatureInt: Math.round(temperature)
    readonly property int gpuTemperatureInt: Math.round(gpuTemperature)
    readonly property int gpuPercent: Math.round(gpuUsage * 100)
    readonly property string memoryLabel: formatBytes(memoryUsedBytes)
        + " / " + formatBytes(memoryTotalBytes)
    readonly property string diskLabel: storageAvailable
        ? formatBytes(diskUsedBytes) + " / " + formatBytes(diskTotalBytes) : "Unavailable"
    readonly property string uptimeLabel: formatUptime(uptimeSeconds)
    readonly property string summaryLabel: "CPU " + cpuPercent + "%"
    readonly property string summaryDetail: "RAM " + memoryPercent + "%"
        + (temperatureAvailable ? " · " + temperatureInt + "°C" : "")

    property IpcHandler metricsIpc: IpcHandler {
        target: "system-metrics"

        function status(): string {
            return "CPU=" + root.cpuPercent
                + " CPU_TEMP=" + (root.temperatureAvailable
                    ? root.temperatureInt : "NA")
                + " GPU=" + (root.gpuUsageAvailable ? root.gpuPercent : "NA")
                + " GPU_TEMP=" + (root.gpuTemperatureAvailable
                    ? root.gpuTemperatureInt : "NA")
                + " GPU_TEMP_PATH=" + root.gpuTemperaturePath
                + " GPU_LOAD_PATH=" + root.gpuLoadPath
        }
    }

    function parseCpu(text): void {
        const line = text.split("\n")[0].trim().split(/\s+/)
        if (line.length < 6 || line[0] !== "cpu")
            return

        let total = 0
        for (let index = 1; index < line.length; index++)
            total += Number(line[index]) || 0
        const idle = (Number(line[4]) || 0) + (Number(line[5]) || 0)

        if (previousCpuTotal > 0 && total > previousCpuTotal) {
            const totalDelta = total - previousCpuTotal
            const idleDelta = idle - previousCpuIdle
            cpuUsage = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta))
        }
        previousCpuTotal = total
        previousCpuIdle = idle
    }

    function parseMemory(text): void {
        const totalMatch = text.match(/^MemTotal:\s+(\d+)\s+kB$/m)
        const availableMatch = text.match(/^MemAvailable:\s+(\d+)\s+kB$/m)
        if (!totalMatch || !availableMatch)
            return

        memoryTotalBytes = Number(totalMatch[1]) * 1024
        memoryUsedBytes = Math.max(0,
            memoryTotalBytes - Number(availableMatch[1]) * 1024)
        memoryUsage = memoryTotalBytes > 0 ? memoryUsedBytes / memoryTotalBytes : 0
    }

    function parseUptime(text): void {
        const value = Number(text.trim().split(/\s+/)[0])
        if (Number.isFinite(value) && value >= 0)
            uptimeSeconds = value
    }

    function parseCpuModel(text): void {
        const match = text.match(/^model name\s*:\s*(.+)$/m)
        if (match && match[1].trim().length > 0)
            cpuModel = match[1].trim()
    }

    function parseOsRelease(text): void {
        const match = text.match(/^PRETTY_NAME=(?:"([^"]+)"|([^\n]+))$/m)
        const value = match ? (match[1] || match[2] || "").trim() : ""
        if (value.length > 0)
            osName = value
    }

    function parseGpuModels(text): void {
        const models = []
        for (const line of text.split("\n")) {
            if (!line.includes("VGA compatible controller")
                    && !line.includes("3D controller"))
                continue
            const fields = []
            const expression = /"([^"]*)"/g
            let match
            while ((match = expression.exec(line)) !== null)
                fields.push(match[1])
            if (fields.length < 3)
                continue
            const bracketed = fields[2].match(/\[([^\]]+)\]/)
            const model = (bracketed ? bracketed[1] : fields[2]).trim()
            if (model.length > 0 && !models.includes(model))
                models.push(model)
        }
        gpuAvailable = models.length > 0
        gpuModel = gpuAvailable ? models.join(" · ") : "Graphics unavailable"
    }

    function parseTemperature(text): void {
        const value = Number(text.trim()) / 1000
        temperatureAvailable = Number.isFinite(value) && value > -50 && value < 200
        if (temperatureAvailable)
            temperature = value
    }

    function parseGpuTemperature(text): void {
        const value = Number(text.trim()) / 1000
        gpuTemperatureAvailable = Number.isFinite(value)
            && value > -50 && value < 200
        if (gpuTemperatureAvailable)
            gpuTemperature = value
    }

    function parseGpuUsage(text): void {
        const value = Number(text.trim())
        gpuUsageAvailable = Number.isFinite(value) && value >= 0 && value <= 100
        if (gpuUsageAvailable)
            gpuUsage = value / 100
    }

    function sensorField(output: string, field: string): string {
        const prefix = field + "="
        for (const line of output.split("\n")) {
            if (line.startsWith(prefix))
                return line.substring(prefix.length)
        }
        return ""
    }

    function applySensorPaths(output: string): void {
        const cpuPath = sensorField(output, "CPU_TEMP_PATH")
        const gpuTempPath = sensorField(output, "GPU_TEMP_PATH")
        const gpuBusyPath = sensorField(output, "GPU_LOAD_PATH")
        if (cpuPath.length > 0)
            cpuTemperaturePath = cpuPath
        gpuTemperaturePath = gpuTempPath
        gpuLoadPath = gpuBusyPath
        temperatureStats.reload()
        if (gpuTemperaturePath.length > 0)
            gpuTemperatureStats.reload()
        else
            gpuTemperatureAvailable = false
        if (gpuLoadPath.length > 0)
            gpuLoadStats.reload()
        else
            gpuUsageAvailable = false
    }

    function parseDisk(text): void {
        const lines = text.trim().split("\n")
        if (lines.length < 2)
            return
        const fields = lines[lines.length - 1].trim().split(/\s+/)
        if (fields.length < 5)
            return

        const total = Number(fields[0])
        const used = Number(fields[1])
        if (!Number.isFinite(total) || !Number.isFinite(used) || total <= 0)
            return
        diskTotalBytes = total
        diskUsedBytes = used
        const reportedPercent = Number(fields[3].replace("%", "")) / 100
        diskUsage = Number.isFinite(reportedPercent)
            ? Math.max(0, Math.min(1, reportedPercent))
            : Math.max(0, Math.min(1, used / total))
        storageAvailable = true
    }

    function formatBytes(bytes): string {
        if (!Number.isFinite(bytes) || bytes <= 0)
            return "0 GiB"
        const gibibytes = bytes / 1073741824
        return (gibibytes >= 10 ? Math.round(gibibytes) : gibibytes.toFixed(1)) + " GiB"
    }

    function formatUptime(seconds): string {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "Unavailable"
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return days + "d " + hours + "h"
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m"
    }

    function refreshFastMetrics(): void {
        cpuStats.reload()
        memoryStats.reload()
        uptimeStats.reload()
    }

    property FileView cpuStats: FileView {
        id: cpuStats
        path: "/proc/stat"
        preload: true
        watchChanges: false
        printErrors: true
        onLoaded: root.parseCpu(text())
    }

    property FileView memoryStats: FileView {
        id: memoryStats
        path: "/proc/meminfo"
        preload: true
        watchChanges: false
        printErrors: true
        onLoaded: root.parseMemory(text())
    }

    property FileView uptimeStats: FileView {
        id: uptimeStats
        path: "/proc/uptime"
        preload: true
        watchChanges: false
        printErrors: true
        onLoaded: root.parseUptime(text())
    }

    property FileView cpuInfo: FileView {
        path: "/proc/cpuinfo"
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: root.parseCpuModel(text())
    }

    property FileView osRelease: FileView {
        path: "/etc/os-release"
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: root.parseOsRelease(text())
    }

    property FileView temperatureStats: FileView {
        id: temperatureStats
        path: root.cpuTemperaturePath
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: root.parseTemperature(text())
        onLoadFailed: root.temperatureAvailable = false
    }

    property FileView gpuTemperatureStats: FileView {
        id: gpuTemperatureStats
        path: root.gpuTemperaturePath
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: root.parseGpuTemperature(text())
        onLoadFailed: root.gpuTemperatureAvailable = false
    }

    property FileView gpuLoadStats: FileView {
        id: gpuLoadStats
        path: root.gpuLoadPath
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: root.parseGpuUsage(text())
        onLoadFailed: root.gpuUsageAvailable = false
    }

    property Timer fastTimer: Timer {
        interval: Config.system.metricsInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshFastMetrics()
    }

    property Timer temperatureTimer: Timer {
        interval: Config.system.temperatureInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            temperatureStats.reload()
            if (root.gpuTemperaturePath.length > 0)
                gpuTemperatureStats.reload()
            if (root.gpuLoadPath.length > 0)
                gpuLoadStats.reload()
        }
    }

    property Timer storageTimer: Timer {
        interval: Config.system.storageInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!diskQuery.running)
                diskQuery.running = true
        }
    }

    property Process diskQuery: Process {
        id: diskQuery
        command: ["df", "-B1", "--output=size,used,avail,pcent,target", Config.system.storagePath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseDisk(text)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.storageAvailable = false
        }
    }

    property Process gpuQuery: Process {
        command: ["lspci", "-mm"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseGpuModels(text)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.gpuAvailable = false
        }
    }

    property Process sensorPathQuery: Process {
        command: [Quickshell.shellDir + "/scripts/system-sensor-paths.sh"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.applySensorPaths(text)
        }
    }
}
