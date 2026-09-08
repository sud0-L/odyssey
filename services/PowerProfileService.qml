pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool performanceAvailable: PowerProfiles.hasPerformanceProfile
    readonly property bool available: profile === PowerProfile.PowerSaver
        || profile === PowerProfile.Balanced || profile === PowerProfile.Performance
    readonly property string profileName: nameFor(profile)
    readonly property string profileId: idFor(profile)
    readonly property string icon: iconFor(profile)
    readonly property real visualLevel: levelFor(profile)
    readonly property bool degraded:
        PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    property bool eventsEnabled: false
    readonly property var options: [
        { id: "power-saver", name: "Power saver", icon: iconFor(PowerProfile.PowerSaver),
            available: true },
        { id: "balanced", name: "Balanced", icon: iconFor(PowerProfile.Balanced),
            available: true },
        { id: "performance", name: "Performance", icon: iconFor(PowerProfile.Performance),
            available: performanceAvailable }
    ]

    signal profileSelected(real level, string profileName)

    property IpcHandler powerIpc: IpcHandler {
        target: "power"

        function cycle(): string {
            return root.cycleProfile()
        }
    }

    function idFor(value): string {
        if (value === PowerProfile.PowerSaver)
            return "power-saver"
        if (value === PowerProfile.Performance)
            return "performance"
        return "balanced"
    }

    function nameFor(value): string {
        if (value === PowerProfile.PowerSaver)
            return "Power saver"
        if (value === PowerProfile.Performance)
            return "Performance"
        return "Balanced"
    }

    function iconFor(value): string {
        if (value === PowerProfile.PowerSaver)
            return "󰌪"
        if (value === PowerProfile.Performance)
            return "󰓅"
        return "󰾅"
    }

    function levelFor(value): real {
        if (value === PowerProfile.PowerSaver)
            return 0.28
        if (value === PowerProfile.Performance)
            return 1
        return 0.62
    }

    function setProfile(value): void {
        if (!available)
            return
        if (value === PowerProfile.Performance && !performanceAvailable)
            return
        if (value === PowerProfile.PowerSaver || value === PowerProfile.Balanced
                || value === PowerProfile.Performance)
            PowerProfiles.profile = value
    }

    function setProfileId(id: string): void {
        if (id === "power-saver")
            setProfile(PowerProfile.PowerSaver)
        else if (id === "balanced")
            setProfile(PowerProfile.Balanced)
        else if (id === "performance")
            setProfile(PowerProfile.Performance)
    }

    function cycleProfile(): string {
        if (!available)
            return "POWER_PROFILE_UNAVAILABLE"

        if (profile === PowerProfile.PowerSaver)
            setProfile(PowerProfile.Balanced)
        else if (profile === PowerProfile.Balanced && performanceAvailable)
            setProfile(PowerProfile.Performance)
        else
            setProfile(PowerProfile.PowerSaver)

        return "POWER_PROFILE_CYCLE_SUCCESS"
    }

    property Connections profileEvents: Connections {
        target: PowerProfiles
        function onProfileChanged(): void {
            if (root.eventsEnabled)
                root.profileSelected(root.visualLevel, root.profileName)
        }
    }

    property Timer startupGuard: Timer {
        interval: 900
        running: true
        onTriggered: root.eventsEnabled = true
    }
}
