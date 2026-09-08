import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root
    property string query: ""
    property string copiedEntryId: ""
    property int currentIndex: -1
    property bool clearConfirmationVisible: false
    readonly property var filteredEntries: ClipboardService.entries.filter(entry =>
        !query || (entry.kind === "text" ? entry.preview : entry.search)
            .toLowerCase().indexOf(query.toLowerCase()) >= 0)

    function resetSelection(): void {
        currentIndex = filteredEntries.length > 0 ? 0 : -1
        if (currentIndex >= 0)
            historyList.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function moveSelection(delta: int): void {
        if (filteredEntries.length === 0)
            return
        currentIndex = (Math.max(0, currentIndex) + delta
            + filteredEntries.length) % filteredEntries.length
        historyList.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function restoreSelection(): void {
        if (currentIndex >= 0 && currentIndex < filteredEntries.length)
            ClipboardService.copy(filteredEntries[currentIndex].id)
    }

    function removeSelection(): void {
        if (currentIndex >= 0 && currentIndex < filteredEntries.length)
            ClipboardService.remove(filteredEntries[currentIndex].id)
    }

    function confirmClear(): void {
        if (ClipboardService.entries.length > 0)
            clearConfirmationVisible = true
    }

    function executeClear(): void {
        if (ClipboardService.clearHistory())
            clearConfirmationVisible = false
    }

    onFilteredEntriesChanged: resetSelection()
    onVisibleChanged: {
        if (visible) {
            clearConfirmationVisible = false
            ClipboardService.beginPresentation()
            ClipboardService.refresh()
            Qt.callLater(() => searchField.forceActiveFocus())
        } else ClipboardService.endPresentation()
    }

    Connections {
        target: ClipboardService
        function onCopied(entryId): void {
            root.copiedEntryId = entryId
            copiedFeedback.restart()
        }
        function onCleared(): void {
            root.clearConfirmationVisible = false
            root.currentIndex = -1
        }
    }
    Timer {
        id: copiedFeedback
        interval: 900
        onTriggered: root.copiedEntryId = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Clipboard"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.filteredEntries.length + " history entries"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "󰑐  Refresh"
                        color: refreshHover.hovered ? Theme.primary : Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                        HoverHandler { id: refreshHover }
                        TapHandler { onTapped: ClipboardService.refresh() }
                    }
                    Text {
                        visible: ClipboardService.entries.length > 0
                        text: "󰆴  Clear"
                        color: clearHover.hovered ? Theme.error : Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: root.confirmClear() }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ClipboardService.currentKind === "image" ? 70 : 48
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.72)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant, 0.38)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3
                Rectangle {
                    visible: ClipboardService.currentKind === "image"
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 54
                    radius: Theme.radiusSmall
                    clip: true
                    color: Theme.surfaceContainer
                    Image {
                        anchors.fill: parent
                        source: ClipboardService.thumbnailSource("current")
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Config.clipboard.thumbnailWidth
                        sourceSize.height: Config.clipboard.thumbnailHeight
                    }
                }
                Text {
                    text: ClipboardService.currentKind === "text" ? "󰅌"
                        : ClipboardService.currentKind === "image" ? "󰋩" : "󰋩"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.textBody + 2
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Current selection"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                    }
                    Text {
                        Layout.fillWidth: true
                        text: ClipboardService.currentKind === "text" ? ClipboardService.currentPreview
                            : ClipboardService.currentKind === "image" ? "Image · " + ClipboardService.currentImageFormat
                            : ClipboardService.currentKind === "checking" ? "Checking current selection…"
                            : ClipboardService.currentKind === "unsupported" ? "Image or binary data cannot be previewed"
                            : "Clipboard is empty or unavailable"
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textBody
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Theme.radiusMedium
            color: Theme.surfaceContainerHigh
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space3
                Text { text: "󰍉"; color: Theme.primary; font.family: Config.appearance.monoFontFamily }
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    text: root.query
                    onTextChanged: root.query = text
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    clip: true
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter
                    Text {
                        anchors.fill: parent
                        visible: !searchField.text
                        text: "Search local clipboard history"
                        color: Theme.surfaceVariantText
                        verticalAlignment: Text.AlignVCenter
                        font: searchField.font
                    }

                    Keys.onPressed: event => {
                        if (root.clearConfirmationVisible) {
                            if (event.key === Qt.Key_Escape) {
                                root.clearConfirmationVisible = false
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter) {
                                root.executeClear()
                                event.accepted = true
                            }
                            return
                        }

                        if (event.key === Qt.Key_Down) {
                            root.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Home) {
                            root.currentIndex = root.filteredEntries.length > 0 ? 0 : -1
                            historyList.positionViewAtBeginning()
                            event.accepted = true
                        } else if (event.key === Qt.Key_End) {
                            root.currentIndex = root.filteredEntries.length - 1
                            historyList.positionViewAtEnd()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            root.restoreSelection()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete
                                && (searchField.text.length === 0
                                    || (event.modifiers & Qt.ControlModifier))) {
                            root.removeSelection()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.clearConfirmationVisible
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 44 : 0
            radius: Theme.radiusMedium
            color: Qt.alpha(Theme.error, Theme.dark ? 0.13 : 0.09)
            border.width: 1
            border.color: Qt.alpha(Theme.error, 0.36)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                anchors.rightMargin: Theme.space2
                spacing: Theme.space2

                Text {
                    Layout.fillWidth: true
                    text: "Clear all local clipboard history? This cannot be undone."
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: cancelHover.hovered
                        ? Theme.surfaceContainerHigh : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                    }
                    HoverHandler { id: cancelHover }
                    TapHandler { onTapped: root.clearConfirmationVisible = false }
                }

                Rectangle {
                    Layout.preferredWidth: 98
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: confirmHover.hovered ? Theme.error
                        : Qt.alpha(Theme.error, 0.76)
                    Text {
                        anchors.centerIn: parent
                        text: "Clear history"
                        color: Theme.dark ? Theme.surfaceText : Theme.primaryText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textSmall
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: confirmHover }
                    TapHandler { onTapped: root.executeClear() }
                }
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Animations.fast; easing.type: Animations.emphasizedEase }
            }
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.space1
            model: root.filteredEntries
            currentIndex: root.currentIndex
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: historyList.width
                height: modelData.kind === "image" ? 66 : 44
                radius: Theme.radiusSmall
                color: root.copiedEntryId === modelData.id
                    ? Qt.alpha(Theme.success, 0.24)
                    : index === root.currentIndex
                        ? Qt.alpha(Theme.primaryContainer, 0.62)
                    : rowHover.hovered ? Theme.surfaceContainerHigh
                    : Qt.alpha(Theme.surfaceContainerHigh, 0.52)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space3
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.space3
                            Rectangle {
                                visible: modelData.kind === "image"
                                Layout.preferredWidth: visible ? 54 : 0
                                Layout.preferredHeight: visible ? 46 : 0
                                radius: Theme.radiusSmall
                                clip: true
                                color: Theme.surfaceContainer
                                Image {
                                    anchors.fill: parent
                                    source: ClipboardService.thumbnailSource(modelData.id)
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: Config.clipboard.thumbnailWidth
                                    sourceSize.height: Config.clipboard.thumbnailHeight
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !ClipboardService.thumbnailSource(modelData.id)
                                    text: "󰋩"
                                    color: Theme.surfaceVariantText
                                    font.family: Config.appearance.monoFontFamily
                                }
                            }
                            Text {
                                visible: modelData.kind === "text"
                                text: "󰅌"
                                color: Theme.primary
                                font.family: Config.appearance.monoFontFamily
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.preview
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: Theme.textBody
                            }
                        }
                        HoverHandler { id: rowHover }
                        TapHandler {
                            onTapped: {
                                root.currentIndex = index
                                ClipboardService.copy(modelData.id)
                            }
                        }
                    }
                    Item {
                        Layout.preferredWidth: 28
                        Layout.fillHeight: true
                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            color: deleteHover.hovered ? Theme.error : Theme.surfaceVariantText
                            font.family: Config.appearance.monoFontFamily
                        }
                        HoverHandler { id: deleteHover }
                        TapHandler {
                            onTapped: {
                                root.currentIndex = index
                                ClipboardService.remove(modelData.id)
                            }
                        }
                    }
                }
                Behavior on color { ColorAnimation { duration: Animations.fast } }
                Component.onCompleted: ClipboardService.requestPreview(modelData)
            }
            Text {
                anchors.centerIn: parent
                visible: historyList.count === 0
                text: ClipboardService.loading ? "Loading clipboard…"
                    : ClipboardService.errorMessage || "No matching text entries"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
            }
        }
    }
}
