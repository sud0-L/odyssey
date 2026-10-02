import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root

    property url artworkSource: ""
    property bool active: true
    property bool atmospheric: false
    property url shownSource: ""
    property url outgoingSource: ""
    readonly property bool hasArtwork: shownSource.toString().length > 0
    readonly property bool ready: newImage.status === Image.Ready
        || (outgoing.visible && oldImage.status === Image.Ready)

    function startTransitionWhenReady() {
        if (outgoingSource.toString().length === 0)
            return
        if (!hasArtwork || (newImage.source.toString() === shownSource.toString()
                && (newImage.status === Image.Ready
                    || newImage.status === Image.Error)))
            transition.start()
    }

    function updateArtwork() {
        if (!active) {
            transition.stop()
            outgoingSource = ""
            shownSource = ""
            return
        }
        const next = artworkSource
        if (next.toString() === shownSource.toString())
            return
        transition.stop()
        outgoingSource = shownSource
        shownSource = next
        outgoing.opacity = 1
        incoming.opacity = outgoingSource.toString().length > 0 ? 0 : 1
        Qt.callLater(startTransitionWhenReady)
    }

    onArtworkSourceChanged: updateArtwork()
    onActiveChanged: updateArtwork()
    Component.onCompleted: updateArtwork()

    Item {
        id: outgoing
        anchors.fill: parent
        visible: root.outgoingSource.toString().length > 0
        opacity: 1

        Image {
            id: oldImage
            anchors.fill: parent
            source: root.outgoingSource
            sourceSize.width: root.atmospheric ? 128 : -1
            sourceSize.height: root.atmospheric ? 128 : -1
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: true
            layer.enabled: root.active && root.atmospheric
        }
        MultiEffect {
            anchors.fill: parent
            source: oldImage
            visible: root.atmospheric && oldImage.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: 1.0
        }
    }

    Item {
        id: incoming
        anchors.fill: parent
        visible: root.hasArtwork
        opacity: 1

        Image {
            id: newImage
            anchors.fill: parent
            source: root.shownSource
            sourceSize.width: root.atmospheric ? 128 : -1
            sourceSize.height: root.atmospheric ? 128 : -1
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: true
            layer.enabled: root.active && root.atmospheric
            onStatusChanged: {
                if (status === Image.Ready || status === Image.Error)
                    root.startTransitionWhenReady()
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: newImage
            visible: root.atmospheric && newImage.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: 1.0
        }
    }

    ParallelAnimation {
        id: transition
        NumberAnimation {
            target: outgoing
            property: "opacity"
            to: 0
            duration: Animations.large
            easing.type: Animations.standardEase
        }
        NumberAnimation {
            target: incoming
            property: "opacity"
            to: 1
            duration: Animations.large
            easing.type: Animations.standardEase
        }
        onFinished: root.outgoingSource = ""
    }
}
