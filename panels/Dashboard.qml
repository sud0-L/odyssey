import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    signal pageRequested(string page)
    readonly property bool centerVisible: Config.dashboard.showMedia
        || Config.dashboard.showSystem

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        DashboardHeroRow {
            visible: Config.dashboard.showHero
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 104 : 0
            Layout.minimumHeight: visible ? 104 : 0
            Layout.maximumHeight: visible ? 104 : 0
            onPageRequested: page => root.pageRequested(page)
        }

        RowLayout {
            visible: root.centerVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space2

            DashboardMediaCard {
                visible: Config.dashboard.showMedia
                Layout.fillWidth: true
                Layout.fillHeight: true
                onPageRequested: root.pageRequested("media-center")
            }

            DashboardSystemCard {
                visible: Config.dashboard.showSystem
                Layout.fillWidth: !Config.dashboard.showMedia
                Layout.preferredWidth: 232
                Layout.fillHeight: true
                onPageRequested: root.pageRequested("system")
            }
        }

        DashboardQuickStrip {
            visible: Config.dashboard.showQuickStrip
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 48 : 0
            Layout.minimumHeight: visible ? 48 : 0
            Layout.maximumHeight: visible ? 48 : 0
            onPageRequested: page => root.pageRequested(page)
        }
    }
}
