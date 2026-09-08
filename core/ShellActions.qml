pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    signal launcherToggleRequested()
    signal launcherOpenRequested()
    signal launcherCloseRequested()
    signal controlCenterToggleRequested()
    signal controlCenterOpenRequested()
    signal controlCenterCloseRequested()
    signal clipboardToggleRequested()
    signal clipboardOpenRequested()
    signal clipboardCloseRequested()
    signal notificationsToggleRequested()
    signal notificationsOpenRequested()
    signal notificationsCloseRequested()
    signal captureOpenRequested()
    signal captureCloseRequested()
    signal sessionOpenRequested()
    signal sessionCloseRequested()
    signal settingsOpenRequested(string section)
    signal settingsCloseRequested()
    signal insightOpenRequested(string page)

    property IpcHandler launcherIpc: IpcHandler {
        target: "launcher"

        function toggle(): string {
            root.launcherToggleRequested()
            return "LAUNCHER_TOGGLE_SUCCESS"
        }

        function open(): string {
            root.launcherOpenRequested()
            return "LAUNCHER_OPEN_SUCCESS"
        }

        function close(): string {
            root.launcherCloseRequested()
            return "LAUNCHER_CLOSE_SUCCESS"
        }
    }

    property IpcHandler controlCenterIpc: IpcHandler {
        target: "control-center"

        function toggle(): string {
            root.controlCenterToggleRequested()
            return "CONTROL_CENTER_TOGGLE_SUCCESS"
        }

        function open(): string {
            root.controlCenterOpenRequested()
            return "CONTROL_CENTER_OPEN_SUCCESS"
        }

        function close(): string {
            root.controlCenterCloseRequested()
            return "CONTROL_CENTER_CLOSE_SUCCESS"
        }
    }

    property IpcHandler clipboardIpc: IpcHandler {
        target: "clipboard"

        function toggle(): string {
            root.clipboardToggleRequested()
            return "CLIPBOARD_TOGGLE_SUCCESS"
        }

        function open(): string {
            root.clipboardOpenRequested()
            return "CLIPBOARD_OPEN_SUCCESS"
        }

        function close(): string {
            root.clipboardCloseRequested()
            return "CLIPBOARD_CLOSE_SUCCESS"
        }
    }

    property IpcHandler notificationsIpc: IpcHandler {
        target: "notifications"

        function toggle(): string {
            root.notificationsToggleRequested()
            return "NOTIFICATIONS_TOGGLE_SUCCESS"
        }

        function open(): string {
            root.notificationsOpenRequested()
            return "NOTIFICATIONS_OPEN_SUCCESS"
        }

        function close(): string {
            root.notificationsCloseRequested()
            return "NOTIFICATIONS_CLOSE_SUCCESS"
        }
    }

    property IpcHandler capturePageIpc: IpcHandler {
        target: "capture-page"

        function open(): string {
            root.captureOpenRequested()
            return "CAPTURE_PAGE_OPEN_SUCCESS"
        }
        function close(): string {
            root.captureCloseRequested()
            return "CAPTURE_PAGE_CLOSE_SUCCESS"
        }
    }

    property IpcHandler sessionPageIpc: IpcHandler {
        target: "session-page"

        function open(): string {
            root.sessionOpenRequested()
            return "SESSION_PAGE_OPEN_SUCCESS"
        }

        function close(): string {
            root.sessionCloseRequested()
            return "SESSION_PAGE_CLOSE_SUCCESS"
        }
    }

    property IpcHandler settingsPageIpc: IpcHandler {
        target: "settings"

        function open(): string {
            root.settingsOpenRequested("appearance")
            return "SETTINGS_OPEN_SUCCESS"
        }

        function island(): string {
            root.settingsOpenRequested("island")
            return "SETTINGS_ISLAND_OPEN_SUCCESS"
        }

        function idle(): string {
            root.settingsOpenRequested("idle")
            return "SETTINGS_IDLE_OPEN_SUCCESS"
        }

        function displays(): string {
            root.settingsOpenRequested("displays")
            return "SETTINGS_DISPLAYS_OPEN_SUCCESS"
        }

        function notifications(): string {
            root.settingsOpenRequested("notifications")
            return "SETTINGS_NOTIFICATIONS_OPEN_SUCCESS"
        }

        function media(): string {
            root.settingsOpenRequested("media")
            return "SETTINGS_MEDIA_OPEN_SUCCESS"
        }

        function wallpaper(): string {
            root.settingsOpenRequested("wallpaper")
            return "SETTINGS_WALLPAPER_OPEN_SUCCESS"
        }

        function dashboard(): string {
            root.settingsOpenRequested("dashboard")
            return "SETTINGS_DASHBOARD_OPEN_SUCCESS"
        }

        function shortcuts(): string {
            root.settingsOpenRequested("shortcuts")
            return "SETTINGS_SHORTCUTS_OPEN_SUCCESS"
        }

        function close(): string {
            root.settingsCloseRequested()
            return "SETTINGS_CLOSE_SUCCESS"
        }
    }

    property IpcHandler insightsIpc: IpcHandler {
        target: "insights"

        function dashboard(): string {
            root.insightOpenRequested("overview")
            return "DASHBOARD_OPEN_SUCCESS"
        }

        function weather(): string {
            root.insightOpenRequested("weather")
            return "WEATHER_OPEN_SUCCESS"
        }

        function calendar(): string {
            root.insightOpenRequested("calendar")
            return "CALENDAR_OPEN_SUCCESS"
        }

        function media(): string {
            root.insightOpenRequested("media-center")
            return "MEDIA_OPEN_SUCCESS"
        }

        function system(): string {
            root.insightOpenRequested("system")
            return "SYSTEM_OPEN_SUCCESS"
        }

        function battery(): string {
            root.insightOpenRequested("battery")
            return "BATTERY_OPEN_SUCCESS"
        }

        function wallpaper(): string {
            root.insightOpenRequested("wallpaper")
            return "WALLPAPER_OPEN_SUCCESS"
        }

        function personalize(): string {
            root.insightOpenRequested("identity-image")
            return "PERSONAL_IMAGE_OPEN_SUCCESS"
        }

        function clipboard(): string {
            root.insightOpenRequested("clipboard")
            return "CLIPBOARD_OPEN_SUCCESS"
        }
    }
}
