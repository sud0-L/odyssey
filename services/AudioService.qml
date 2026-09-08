pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: Pipewire.ready && sink?.audio !== null && sink?.audio !== undefined
    readonly property bool microphoneAvailable: Pipewire.ready
        && source?.audio !== null && source?.audio !== undefined
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property real microphoneVolume: microphoneAvailable ? source.audio.volume : 0
    readonly property int microphonePercent: Math.round(microphoneVolume * 100)
    readonly property bool microphoneMuted: microphoneAvailable ? source.audio.muted : false
    readonly property string outputName: displayName(sink, "No output")
    readonly property string inputName: displayName(source, "No microphone")
    readonly property var outputDevices: Pipewire.nodes.values.filter(node =>
        node?.audio && node.isSink && !node.isStream)
    readonly property var inputDevices: Pipewire.nodes.values.filter(node =>
        node?.audio && !node.isSink && !node.isStream)

    property bool eventsEnabled: false
    property bool outputEventScheduled: false
    property bool microphoneEventScheduled: false

    signal outputLevelChanged(real level, bool muted, string deviceName)
    signal microphoneLevelChanged(real level, bool muted, string deviceName)

    property IpcHandler audioIpc: IpcHandler {
        target: "audio"

        function increment(step: int): string {
            return root.adjustVolume(Math.abs(Number(step)))
        }

        function decrement(step: int): string {
            return root.adjustVolume(-Math.abs(Number(step)))
        }

        function mute(): string {
            if (!root.available)
                return "AUDIO_OUTPUT_UNAVAILABLE"
            root.toggleMute()
            return "AUDIO_MUTE_TOGGLE_SUCCESS"
        }

        function micmute(): string {
            if (!root.microphoneAvailable)
                return "AUDIO_INPUT_UNAVAILABLE"
            root.toggleMicrophoneMute()
            return "MICROPHONE_MUTE_TOGGLE_SUCCESS"
        }
    }

    function displayName(node, fallback): string {
        if (!node)
            return fallback
        return node.nickname || node.description || node.name || fallback
    }

    function setVolume(percent): void {
        if (!available)
            return
        const clamped = Math.max(0, Math.min(Config.audio.maxVolumePercent, percent))
        sink.audio.volume = clamped / 100
        if (clamped > 0 && sink.audio.muted)
            sink.audio.muted = false
    }

    function adjustVolume(delta): string {
        if (!available)
            return "AUDIO_OUTPUT_UNAVAILABLE"
        const numericDelta = Number(delta)
        if (!Number.isFinite(numericDelta) || numericDelta === 0)
            return "AUDIO_INVALID_STEP"
        setVolume(volumePercent + numericDelta)
        return "AUDIO_VOLUME_ADJUST_SUCCESS"
    }

    function toggleMute(): void {
        if (available)
            sink.audio.muted = !sink.audio.muted
    }

    function toggleMicrophoneMute(): void {
        if (microphoneAvailable)
            source.audio.muted = !source.audio.muted
    }

    function setOutputDevice(node): bool {
        if (!node || !outputDevices.includes(node))
            return false
        Pipewire.preferredDefaultAudioSink = node
        return true
    }

    function setInputDevice(node): bool {
        if (!node || !inputDevices.includes(node))
            return false
        Pipewire.preferredDefaultAudioSource = node
        return true
    }

    function scheduleOutputEvent(): void {
        if (!eventsEnabled || outputEventScheduled)
            return
        outputEventScheduled = true
        Qt.callLater(() => {
            root.outputEventScheduled = false
            root.outputLevelChanged(root.volume, root.muted, root.outputName)
        })
    }

    function scheduleMicrophoneEvent(): void {
        if (!eventsEnabled || microphoneEventScheduled)
            return
        microphoneEventScheduled = true
        Qt.callLater(() => {
            root.microphoneEventScheduled = false
            root.microphoneLevelChanged(root.microphoneVolume, root.microphoneMuted, root.inputName)
        })
    }

    property PwObjectTracker nodeTracker: PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node?.audio && !node.isStream)
    }

    property Connections sinkEvents: Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged(): void {
            root.scheduleOutputEvent()
        }
        function onMutedChanged(): void {
            root.scheduleOutputEvent()
        }
    }

    property Connections sourceEvents: Connections {
        target: root.source?.audio ?? null
        function onVolumesChanged(): void {
            root.scheduleMicrophoneEvent()
        }
        function onMutedChanged(): void {
            root.scheduleMicrophoneEvent()
        }
    }

    property Timer startupGuard: Timer {
        interval: 900
        running: Pipewire.ready
        onTriggered: root.eventsEnabled = true
    }
}
