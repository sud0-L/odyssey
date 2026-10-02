pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../core"

Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    property MprisPlayer activePlayer: null
    property bool selectionPinned: false
    property real position: 0
    property bool eventsEnabled: false

    readonly property bool available: activePlayer !== null
    readonly property int playerCount: players.length
    readonly property string identity: activePlayer?.identity || "Media"
    readonly property string title: activePlayer?.trackTitle || "Unknown track"
    readonly property string artist: activePlayer?.trackArtist || identity
    readonly property string album: activePlayer?.trackAlbum || ""
    readonly property url artwork: activePlayer?.trackArtUrl || ""
    readonly property real duration: activePlayer?.lengthSupported
        ? Math.max(0, activePlayer.length) : 0
    readonly property real progress: duration > 0
        ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property bool playing: activePlayer?.playbackState
        === MprisPlaybackState.Playing
    readonly property bool paused: activePlayer?.playbackState
        === MprisPlaybackState.Paused
    readonly property bool canToggle: activePlayer?.canTogglePlaying
        || (playing ? activePlayer?.canPause : activePlayer?.canPlay) || false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canNext: activePlayer?.canGoNext ?? false
    readonly property bool canSeek: activePlayer?.canSeek ?? false
    readonly property bool hoverVisible: Config.media.hoverMode === "available"
        ? available : Config.media.hoverMode === "playing" ? playing : false

    signal presentationRequested()
    signal presentationDismissRequested()

    function isIdle(player: MprisPlayer): bool {
        return player !== null
            && player.playbackState === MprisPlaybackState.Stopped
            && !player.trackTitle && !player.trackArtist
    }

    function resolveActivePlayer(): void {
        const candidates = players.filter(player => player && player.canControl
            && !isIdle(player))
        const detailed = candidates.filter(player => player.trackArtist
            || player.trackAlbum)
        // Keep the selected track through pause. A browser tab can report
        // Playing at the same time and must not silently take over the controls.
        if (activePlayer && players.indexOf(activePlayer) >= 0
                && !isIdle(activePlayer)) {
            // MPRIS metadata often arrives after the player list. Promote a
            // richer track unless the user explicitly selected this player.
            if (!selectionPinned && !activePlayer.trackArtist
                    && !activePlayer.trackAlbum && detailed.length > 0) {
                activePlayer = (Config.media.preferPlaying
                    ? detailed.find(player => player.isPlaying) : null)
                    || detailed[0]
            }
            return
        }

        selectionPinned = false
        // Prefer an actual track's metadata over a browser tab's page title.
        const pool = detailed.length > 0 ? detailed : candidates
        activePlayer = (Config.media.preferPlaying
            ? pool.find(player => player.isPlaying) : null) || pool[0] || null
    }

    function selectPlayer(player: MprisPlayer): void {
        if (player && players.indexOf(player) >= 0) {
            selectionPinned = true
            activePlayer = player
        }
    }

    function selectNextPlayer(): void {
        if (players.length < 2)
            return
        const currentIndex = Math.max(0, players.indexOf(activePlayer))
        for (let offset = 1; offset <= players.length; ++offset) {
            const candidate = players[(currentIndex + offset) % players.length]
            if (candidate && !isIdle(candidate)) {
                selectionPinned = true
                activePlayer = candidate
                return
            }
        }
    }

    function setPresentationsEnabled(enabled: bool): void {
        SettingsStore.setMediaToggle("enabled", enabled)
        if (!enabled)
            presentationDismissRequested()
    }

    function setPreferPlaying(enabled: bool): void {
        if (SettingsStore.setMediaToggle("preferPlaying", enabled))
            resolveActivePlayer()
    }

    function setPresentationTimeout(milliseconds: real): void {
        SettingsStore.setMediaPresentationTimeout(milliseconds)
    }

    function setHoverMode(mode: string): void {
        SettingsStore.setMediaHoverMode(mode)
    }

    function resetPreferences(): void {
        SettingsStore.resetMedia()
        resolveActivePlayer()
    }

    function togglePlaying(): void {
        if (playing) {
            if (activePlayer?.canPause)
                activePlayer.pause()
            else if (activePlayer?.canTogglePlaying)
                activePlayer.togglePlaying()
        } else if (activePlayer?.canPlay) {
            activePlayer.play()
        } else if (activePlayer?.canTogglePlaying) {
            activePlayer.togglePlaying()
        }
    }

    function previous(): void {
        if (canPrevious)
            activePlayer.previous()
    }

    function next(): void {
        if (canNext)
            activePlayer.next()
    }

    function seekTo(fraction: real): void {
        if (canSeek && duration > 0)
            activePlayer.position = Math.max(0, Math.min(1, fraction)) * duration
    }

    function refreshPosition(): void {
        if (activePlayer?.positionSupported)
            position = Math.max(0, activePlayer.position)
    }

    function queuePresentation(): void {
        const player = activePlayer
        if (eventsEnabled && player && player.trackTitle)
            presentationDebounce.restart()
    }

    onPlayersChanged: resolveActivePlayer()
    onActivePlayerChanged: {
        position = 0
        refreshPosition()
        if (eventsEnabled)
            queuePresentation()
    }

    Instantiator {
        model: root.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData

            function onIsPlayingChanged(): void {
                root.resolveActivePlayer()
            }

            function onTrackChanged(): void {
                if (modelData === root.activePlayer) {
                    root.position = 0
                    root.refreshPosition()
                }
                root.resolveActivePlayer()
                root.queuePresentation()
            }
        }
    }

    Connections {
        target: root.activePlayer

        function onPlaybackStateChanged(): void {
            root.resolveActivePlayer()
            root.refreshPosition()
            root.queuePresentation()
        }

        function onPositionChanged(): void {
            root.refreshPosition()
        }

        function onLengthChanged(): void {
            root.refreshPosition()
        }
    }

    Timer {
        id: positionTimer
        interval: Config.media.positionInterval
        repeat: true
        running: root.playing
        onTriggered: root.refreshPosition()
    }

    Timer {
        id: presentationDebounce
        interval: 180
        onTriggered: root.presentationRequested()
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            root.resolveActivePlayer()
            root.eventsEnabled = true
        }
    }
}
