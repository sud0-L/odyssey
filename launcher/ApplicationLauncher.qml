import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    property var results: CommandPaletteService.search(searchField.text,
        Config.launcher.resultLimit)
    property int currentIndex: firstEnabledIndex()
    signal dismissRequested()
    signal pageRequested(string page)

    function firstEnabledIndex(): int {
        for (let i = 0; i < results.length; ++i) {
            if (results[i].enabled)
                return i
        }
        return -1
    }

    function moveSelection(delta: int): void {
        if (results.length === 0)
            return
        let candidate = currentIndex
        for (let i = 0; i < results.length; ++i) {
            candidate = (candidate + delta + results.length) % results.length
            if (results[candidate].enabled)
                break
        }
        currentIndex = candidate
        resultList.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function activateCurrent(): void {
        if (currentIndex < 0 || currentIndex >= results.length)
            return
        const outcome = CommandPaletteService.execute(results[currentIndex])
        if (!outcome?.handled)
            return
        if (outcome.page)
            pageRequested(outcome.page)
        else if (outcome.dismiss)
            dismissRequested()
    }

    onResultsChanged: {
        currentIndex = firstEnabledIndex()
        if (visible)
            resultRefresh.restart()
    }
    onVisibleChanged: {
        if (visible) {
            ClipboardService.refresh()
            searchField.text = ""
            Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.radiusMedium
            color: Theme.surfaceContainerHigh
            border.width: searchField.activeFocus ? 1 : 0
            border.color: Qt.alpha(Theme.primary, 0.58)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                anchors.rightMargin: Theme.space3
                spacing: Theme.space2

                Text {
                    text: "󰍉"
                    color: Theme.primary
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: Theme.iconSmall
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerText
                    clip: true
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.textBody

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchField.text.length === 0
                        text: "Search Odyssey"
                        color: Theme.surfaceVariantText
                        font: searchField.font
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            root.activateCurrent()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.dismissRequested()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    text: root.results.length.toString()
                    color: Theme.surfaceVariantText
                    font.family: Config.appearance.monoFontFamily
                    font.pixelSize: 10
                }
            }
        }

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.space1
            model: root.results
            currentIndex: root.currentIndex

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Animations.fast
                        easing.type: Animations.emphasizedEase
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.98
                        to: 1
                        duration: Animations.fast
                        easing.type: Animations.emphasizedEase
                    }
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Math.round(Animations.fast * 0.6)
                    easing.type: Animations.emphasizedEase
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Animations.normal
                    easing.type: Animations.standardEase
                }
            }

            delegate: PaletteResult {
                required property int index
                required property var modelData
                width: resultList.width
                result: modelData
                selected: index === root.currentIndex
                onPointed: root.currentIndex = index
                onActivated: {
                    root.currentIndex = index
                    root.activateCurrent()
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: "No matching Odyssey results"
                color: Theme.surfaceVariantText
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.textBody
            }
        }
    }

    SequentialAnimation {
        id: resultRefresh
        NumberAnimation {
            target: resultList
            property: "opacity"
            to: 0.78
            duration: Math.round(Animations.fast * 0.35)
            easing.type: Animations.emphasizedEase
        }
        NumberAnimation {
            target: resultList
            property: "opacity"
            to: 1
            duration: Math.round(Animations.fast * 0.65)
            easing.type: Animations.emphasizedEase
        }
    }
}
