import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property var monitor
    property bool selectionMode: false
    readonly property var filteredWallpapers:
        WallpaperService.filterWallpapers(searchInput.text)
    readonly property string monitorName: monitor?.name || ""
    signal selectionCompleted()
    signal cancelRequested()

    function activateImage(image): void {
        if (!selectionMode) {
            WallpaperService.applyWallpaper(image.path, monitorName)
            return
        }
        if (IdentityService.setPersonalImage(image.source))
            selectionCompleted()
    }

    onVisibleChanged: {
        if (visible && !selectionMode && Config.wallpaper.refreshOnOpen)
            WallpaperService.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: Theme.space2

            ColumnLayout {
                // Nested layouts are expansive by default. Keep the heading at
                // its intended width so the search field owns the flexible
                // space in this row.
                Layout.fillWidth: false
                Layout.preferredWidth: root.selectionMode ? 170 : 190
                spacing: 0
                Text {
                    text: root.selectionMode ? "Personal image" : "Wallpaper"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selectionMode
                        ? "Choose from your wallpaper library"
                        : WallpaperService.statusLabel
                    color: !root.selectionMode
                            && WallpaperService.errorMessage.length > 0
                        ? Theme.warning : Theme.surfaceVariantText
                    elide: Text.ElideRight
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: root.width > 520
                // Keep the hidden item out of sizing entirely; the compact
                // header deliberately has no search control.
                Layout.fillWidth: false
                Layout.minimumWidth: 0
                Layout.maximumWidth: visible ? Number.POSITIVE_INFINITY : 0
                Layout.preferredWidth: visible ? 228 : 0
                Layout.preferredHeight: 34
                radius: Theme.radiusMedium
                color: Qt.alpha(Theme.surfaceContainerHigh, 0.62)
                // Keep every search child inside the width assigned by the
                // header layout, including during layout/visibility changes.
                clip: true
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space2
                    Text {
                        text: "󰍉"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 13
                    }
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.surfaceText
                        selectionColor: Theme.primaryContainer
                        selectedTextColor: Theme.primaryContainerText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 11
                        clip: true

                        Text {
                            visible: searchInput.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.selectionMode
                                ? "Search images" : "Search wallpapers"
                            color: Theme.surfaceVariantText
                            font: searchInput.font
                        }
                    }
                }
            }

            TextButton {
                visible: root.selectionMode
                Layout.preferredHeight: 34
                text: "Back"
                onClicked: root.cancelRequested()
            }

            TextButton {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 68
                // Refresh is a mouse utility action: retain the ordinary
                // pressed/hover response without a persistent focus outline
                // or a loading-label swap that makes the header flicker.
                showFocusIndicator: false
                text: "Refresh"
                onClicked: WallpaperService.refresh()
            }
        }

        Rectangle {
            visible: !root.selectionMode && WallpaperService.backendState !== "ready"
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 52 : 0
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.72)
            border.width: 1
            border.color: WallpaperService.errorMessage.length > 0 ? Theme.warning
                : Qt.alpha(Theme.outlineVariant, 0.45)
            RowLayout {
                anchors.fill: parent; anchors.margins: Theme.space2; spacing: Theme.space2
                ColumnLayout { Layout.fillWidth: true; spacing: 1
                    Text { text: "Wallpaper setup"; color: Theme.surfaceText; font.family: Config.appearance.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: WallpaperService.backendDetail; color: Theme.surfaceVariantText; font.family: Config.appearance.fontFamily; font.pixelSize: 9; elide: Text.ElideRight }
                }
                TextButton { visible: WallpaperService.backendState !== "ready"; text: "Check again"; onClicked: WallpaperService.retry() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.surfaceContainerLow, 0.48)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.32)
            clip: true

            GridView {
                id: gallery
                anchors.fill: parent
                anchors.margins: Theme.space2
                clip: true
                model: root.filteredWallpapers
                cellWidth: width / Config.wallpaper.galleryColumns
                cellHeight: Config.wallpaper.cardHeight
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true

                delegate: Item {
                    required property var modelData
                    width: gallery.cellWidth
                    height: gallery.cellHeight

                    WallpaperCard {
                        anchors.fill: parent
                        anchors.margins: 4
                        wallpaper: modelData
                        current: root.selectionMode
                            ? modelData.source === IdentityService.personalImageSource.toString()
                            : modelData.path === WallpaperService.currentWallpaper
                        applying: !root.selectionMode
                            && modelData.path === WallpaperService.pendingWallpaper
                        currentLabel: root.selectionMode ? "SELECTED" : "ACTIVE"
                        onActivated: root.activateImage(modelData)
                    }
                }
            }

            ColumnLayout {
                visible: !WallpaperService.loading
                    && root.filteredWallpapers.length === 0
                anchors.centerIn: parent
                spacing: Theme.space2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰸉"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 28
                }
                Text {
                    text: searchInput.text.length > 0
                        ? (root.selectionMode ? "No matching images"
                            : "No matching wallpapers")
                        : (root.selectionMode ? "No images discovered"
                            : "No wallpapers discovered")
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                }
            }
        }
    }
}
