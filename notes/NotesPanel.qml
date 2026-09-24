import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

FocusScope {
    id: root

    property bool active: false
    property string selectedId: ""
    property bool editing: selectedId.length > 0
    property bool loadingEditor: false
    property bool confirmDelete: false
    signal closeRequested()

    readonly property var filteredNotes: {
        NotesService.revision
        const query = searchInput.text.trim().toLocaleLowerCase()
        if (!query)
            return NotesService.notes
        return NotesService.notes.filter(note =>
            note.title.toLocaleLowerCase().includes(query)
                || note.content.toLocaleLowerCase().includes(query))
    }

    function displayTitle(note): string {
        const title = note?.title?.trim() || ""
        return title || "Untitled note"
    }

    function preview(note): string {
        const content = (note?.content || "").replace(/\s+/g, " ").trim()
        return content || "No additional text"
    }

    function dateLabel(note): string {
        const value = new Date(note?.updated || "")
        if (Number.isNaN(value.getTime()))
            return ""
        const today = new Date()
        return value.toDateString() === today.toDateString()
            ? Qt.formatTime(value, Config.appearance.use24HourClock
                ? "HH:mm" : "h:mm AP")
            : Qt.formatDate(value, "MMM d")
    }

    function openNote(noteId): void {
        const selected = NotesService.note(noteId)
        if (!selected)
            return
        loadingEditor = true
        selectedId = noteId
        titleInput.text = selected.title
        contentInput.text = selected.content
        confirmDelete = false
        Qt.callLater(() => {
            loadingEditor = false
            titleInput.forceActiveFocus()
        })
    }

    function closeEditor(): void {
        NotesService.flushPendingSave()
        confirmDelete = false
        selectedId = ""
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    function commitEditor(): void {
        if (!loadingEditor && selectedId)
            NotesService.updateNote(selectedId, titleInput.text,
                contentInput.text)
    }

    function newNote(): void {
        NotesService.createNote()
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(() => editing ? titleInput.forceActiveFocus()
                : searchInput.forceActiveFocus())
        else
            NotesService.flushPendingSave()
    }

    Keys.onEscapePressed: {
        if (confirmDelete)
            confirmDelete = false
        else if (editing)
            closeEditor()
        else
            closeRequested()
    }

    Item {
        id: listPage
        anchors.fill: parent
        enabled: !root.editing
        z: root.editing ? 0 : 1
        opacity: root.editing ? 0 : 1
        x: root.editing ? -Math.round(width * 0.18) : 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space1

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Notes"
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: NotesService.notes.length === 1
                            ? "1 note" : NotesService.notes.length + " notes"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                IconButton {
                    glyph: "+"
                    accessibleName: "New note"
                    emphasized: true
                    compact: true
                    onClicked: root.newNote()
                }

                IconButton {
                    glyph: "󰅖"
                    accessibleName: "Close Notes"
                    compact: true
                    onClicked: root.closeRequested()
                }

            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusMedium
                color: searchFocus.activeFocus
                    ? Qt.alpha(Theme.primaryContainer, 0.44)
                    : Qt.alpha(Theme.surfaceContainerHigh, 0.66)
                border.width: 1
                border.color: searchFocus.activeFocus
                    ? Theme.primary : Qt.alpha(Theme.outlineVariant, 0.42)

                FocusScope {
                    id: searchFocus
                    anchors.fill: parent
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.leftMargin: 36
                        anchors.right: clearSearch.left
                        anchors.rightMargin: Theme.space1
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.surfaceText
                        selectionColor: Theme.primaryContainer
                        selectedTextColor: Theme.primaryContainerText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textBody
                        clip: true
                        activeFocusOnTab: true
                        Keys.onDownPressed: notesList.forceActiveFocus()
                    }
                    Text {
                        anchors.left: searchInput.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "Search notes"
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textBody
                    }
                    Text {
                        id: clearSearch
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length > 0
                        text: "󰅖"
                        color: clearHover.hovered ? Theme.surfaceText
                            : Theme.surfaceVariantText
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: Theme.iconSmall
                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: searchInput.clear() }
                    }
                }

                Behavior on color { ColorAnimation { duration: Animations.fast } }
                Behavior on border.color {
                    ColorAnimation { duration: Animations.fast }
                }
            }

            Item {
                id: listViewport
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notesList
                    readonly property int hoveredIndex: {
                        if (!listPointer.containsMouse)
                            return -1
                        const extent = 78 + spacing
                        const contentYPosition = listPointer.mouseY + contentY
                        const candidate = Math.floor(contentYPosition / extent)
                        const withinRow = contentYPosition - candidate * extent
                        return candidate >= 0 && candidate < count
                                && withinRow >= 0 && withinRow < 78
                            ? candidate : -1
                    }
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.space1
                    model: root.filteredNotes
                    boundsBehavior: Flickable.StopAtBounds
                    activeFocusOnTab: true

                    delegate: Rectangle {
                        id: noteRow
                        required property int index
                        required property var modelData
                        width: notesList.width
                        height: 78
                        radius: Theme.radiusMedium
                        color: index === notesList.hoveredIndex
                            ? Qt.alpha(Theme.primary, 0.16) : "transparent"
                        border.width: index === notesList.hoveredIndex
                                || activeFocus ? 1 : 0
                        border.color: index === notesList.hoveredIndex
                            ? Qt.alpha(Theme.primary, 0.52) : Theme.primary
                        activeFocusOnTab: true

                        Keys.onReturnPressed: root.openNote(modelData.id)
                        Keys.onSpacePressed: root.openNote(modelData.id)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.space3
                            anchors.rightMargin: Theme.space3
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: Theme.space2
                                Text {
                                    Layout.fillWidth: true
                                    text: root.displayTitle(noteRow.modelData)
                                    elide: Text.ElideRight
                                    color: Theme.surfaceText
                                    font.family: Config.appearance.fontFamily
                                    font.pixelSize: Theme.textBody
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: root.dateLabel(noteRow.modelData)
                                    color: Theme.surfaceVariantText
                                    font.family: Config.appearance.fontFamily
                                    font.pixelSize: 9
                                }
                            }
                            Text {
                                width: parent.width
                                text: root.preview(noteRow.modelData)
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                color: Theme.surfaceVariantText
                                font.family: Config.appearance.fontFamily
                                font.pixelSize: 10
                                lineHeight: 1.15
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }

                    }

                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.space5 * 2
                    spacing: Theme.space2
                    visible: NotesService.loaded
                        && root.filteredNotes.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchInput.text.length > 0 ? "󰍉" : "󰎞"
                        color: Theme.primary
                        font.family: Config.appearance.monoFontFamily
                        font.pixelSize: 28
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: searchInput.text.length > 0
                            ? "No matching notes" : "A quiet place for your thoughts"
                        color: Theme.surfaceText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.textBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: searchInput.text.length > 0
                            ? "Try a different title or phrase."
                            : "Create a note and it will be saved automatically."
                        color: Theme.surfaceVariantText
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                visible: NotesService.errorMessage.length > 0
                Layout.fillWidth: true
                text: NotesService.errorMessage
                color: Theme.error
                wrapMode: Text.WordWrap
                font.family: Config.appearance.fontFamily
                font.pixelSize: 9
            }
        }

        Behavior on x {
            NumberAnimation { duration: Animations.normal; easing.type: Animations.emphasizedEase }
        }
        Behavior on opacity { NumberAnimation { duration: Animations.fast } }
    }

    Item {
        id: editorPage
        anchors.fill: parent
        enabled: root.editing
        z: root.editing ? 1 : 0
        opacity: root.editing ? (root.confirmDelete ? 0.28 : 1) : 0
        x: root.editing ? 0 : Math.round(width * 0.22)

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.space2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space1
                IconButton {
                    glyph: "󰁍"
                    accessibleName: "Back to notes"
                    onClicked: root.closeEditor()
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: NotesService.saveState
                    color: NotesService.saveState === "Saved"
                        ? Theme.success : Theme.surfaceVariantText
                    opacity: text.length > 0 ? 1 : 0
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 9
                    Behavior on opacity {
                        NumberAnimation { duration: Animations.fast }
                    }
                }
                IconButton {
                    glyph: "󰆴"
                    accessibleName: "Delete note"
                    danger: true
                    onClicked: root.confirmDelete = true
                }
                IconButton {
                    glyph: "󰅖"
                    accessibleName: "Close Notes"
                    compact: true
                    onClicked: root.closeRequested()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                TextInput {
                    id: titleInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    maximumLength: 500
                    activeFocusOnTab: true
                    onTextEdited: root.commitEditor()
                    Keys.onTabPressed: contentInput.forceActiveFocus()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: titleInput.text.length === 0
                    text: "Untitled note"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Theme.outlineVariant, 0.46)
            }

            Flickable {
                id: editorScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, contentInput.implicitHeight)
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: contentInput
                    width: editorScroll.width
                    height: Math.max(editorScroll.height, implicitHeight)
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerText
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    activeFocusOnTab: true
                    selectByMouse: true
                    onTextChanged: root.commitEditor()
                }
                Text {
                    anchors.top: contentInput.top
                    visible: contentInput.text.length === 0
                    text: "Start writing…"
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                }
            }
        }

        Behavior on x {
            NumberAnimation { duration: Animations.normal; easing.type: Animations.emphasizedEase }
        }
        Behavior on opacity { NumberAnimation { duration: Animations.fast } }
    }

    MouseArea {
        id: listPointer
        x: listPage.x + listViewport.x + notesList.x
        y: listPage.y + listViewport.y + notesList.y
        width: notesList.width
        height: notesList.height
        visible: !root.editing
        z: 10
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: false
        scrollGestureEnabled: false
        cursorShape: Qt.ArrowCursor
        onClicked: {
            const index = notesList.hoveredIndex
            if (index >= 0 && index < root.filteredNotes.length)
                root.openNote(root.filteredNotes[index].id)
        }
        onWheel: wheel => wheel.accepted = false
    }

    Rectangle {
        anchors.fill: parent
        visible: root.confirmDelete
        color: "transparent"
        z: 20

        TapHandler { }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(292, parent.width - Theme.space5 * 2)
            height: dialogLayout.implicitHeight + Theme.space3 * 2
            radius: Theme.radiusLarge
            color: Theme.surfaceContainerHigh
            border.width: 0

            ColumnLayout {
                id: dialogLayout
                anchors.fill: parent
                anchors.margins: Theme.space3
                spacing: Theme.space1
                Text {
                    text: "Delete this note?"
                    color: Theme.surfaceText
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "This removes the local note file and cannot be undone."
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: 10
                }
                Item { Layout.preferredHeight: Theme.space2 }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    PanelButton {
                        label: "Cancel"
                        onClicked: root.confirmDelete = false
                    }
                    PanelButton {
                        label: "Delete"
                        danger: true
                        onClicked: {
                            const deleting = root.selectedId
                            root.confirmDelete = false
                            root.selectedId = ""
                            NotesService.deleteNote(deleting)
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: NotesService
        function onNoteCreated(noteId): void { root.openNote(noteId) }
        function onNoteDeleted(noteId): void {
            if (root.selectedId === noteId)
                root.selectedId = ""
        }
    }

    component IconButton: Rectangle {
        id: iconButton
        property string glyph: ""
        property string accessibleName: ""
        property bool danger: false
        property bool emphasized: false
        property bool compact: false
        signal clicked()
        Layout.preferredWidth: compact ? 28 : 34
        Layout.preferredHeight: compact ? 28 : 34
        radius: Theme.radiusSmall
        color: danger ? (iconHover.hovered
                ? Qt.alpha(Theme.error, 0.22) : "transparent")
            : emphasized ? (iconHover.hovered
                ? Theme.primary : Theme.primaryContainer)
            : iconHover.hovered ? Theme.surfaceContainerHigh : "transparent"
        border.width: emphasized || iconHover.hovered ? 1 : 0
        border.color: danger ? Qt.alpha(Theme.error, 0.5)
            : emphasized ? Qt.alpha(Theme.primary, 0.62)
            : Qt.alpha(Theme.outlineVariant, 0.44)
        Accessible.name: accessibleName
        Accessible.role: Accessible.Button
        Text {
            anchors.centerIn: parent
            text: iconButton.glyph
            color: iconButton.danger ? Theme.error
                : iconButton.emphasized
                    ? (iconHover.hovered ? Theme.primaryText
                        : Theme.primaryContainerText)
                    : Theme.surfaceVariantText
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: Theme.iconSmall
        }
        HoverHandler { id: iconHover }
        TapHandler { onTapped: iconButton.clicked() }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    component PanelButton: Rectangle {
        id: panelButton
        property string glyph: ""
        property string label: ""
        property bool emphasized: false
        property bool danger: false
        property bool compact: false
        signal clicked()
        Layout.preferredWidth: buttonContent.implicitWidth
            + (compact ? Theme.space2 * 2 : Theme.space3 * 2)
        Layout.preferredHeight: compact ? 28 : 34
        radius: Theme.radiusSmall
        color: danger ? (buttonHover.hovered
                ? Theme.error : Qt.alpha(Theme.error, 0.14))
            : emphasized ? (buttonHover.hovered
                ? Theme.primary : Theme.primaryContainer)
            : buttonHover.hovered ? Theme.surfaceContainerHigh : "transparent"
        border.width: emphasized || danger || buttonHover.hovered ? 1 : 0
        border.color: danger ? Qt.alpha(Theme.error, 0.62)
            : emphasized ? Qt.alpha(Theme.primary, 0.62)
            : Qt.alpha(Theme.outlineVariant, 0.44)
        RowLayout {
            id: buttonContent
            anchors.centerIn: parent
            spacing: Theme.space1
            Text {
                visible: panelButton.glyph.length > 0
                text: panelButton.glyph
                color: panelButton.danger ? (buttonHover.hovered
                        ? Theme.foregroundFor(Theme.error) : Theme.error)
                    : panelButton.emphasized
                        ? (buttonHover.hovered ? Theme.primaryText
                            : Theme.primaryContainerText)
                        : Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Text {
                text: panelButton.label
                color: panelButton.danger ? (buttonHover.hovered
                        ? Theme.foregroundFor(Theme.error) : Theme.error)
                    : panelButton.emphasized
                        ? (buttonHover.hovered ? Theme.primaryText
                            : Theme.primaryContainerText)
                        : Theme.surfaceText
                font.family: Config.appearance.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
        HoverHandler { id: buttonHover }
        TapHandler { onTapped: panelButton.clicked() }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }
}
