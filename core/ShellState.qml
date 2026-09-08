pragma Singleton
import QtQuick

QtObject {
    id: root

    property date now: new Date()
    readonly property string time: Qt.formatDateTime(now,
        Config.appearance.use24HourClock ? "HH:mm" : "h:mm AP")
    readonly property string dateLabel: Qt.formatDateTime(now, "ddd, MMM d")

    function start(): void {
        refreshClock()
    }

    function refreshClock(): void {
        now = new Date()
        // Wake just after the next minute boundary. The visible clock has no
        // seconds, so a one-second polling timer only creates needless work.
        clock.interval = Math.max(1000, 60050 - (now.getTime() % 60000))
        clock.restart()
    }

    property Timer clock: Timer {
        interval: 1000
        repeat: false
        onTriggered: root.refreshClock()
    }
}
