import "../../services"
import QtQuick

Item {
    id: root

    required property var window

    function step(delta) {
        list.step(delta)
    }

    ListView {
        id: list

        readonly property int repeatCount: 100
        readonly property int imageCount: root.window.filteredImages.length

        readonly property int centerCardWidth: Math.round(300 * 1.9)
        readonly property int centerCardHeight: Math.round(380 * 1.85)
        readonly property int neighborCardWidth: Math.round(300 * 1.15)
        readonly property int bleedPadding: 140

        readonly property int visibleWidth:
            centerCardWidth + neighborCardWidth * 2 + spacing * 2 + bleedPadding

        function realIndex(i) {
            return ((i % imageCount) + imageCount) % imageCount
        }
        

        property bool settled: true

        Timer {
            id: settleTimer
            interval: 180
            onTriggered: list.settled = true
        }

        function step(delta) {
            if (imageCount === 0)
                return
            

            list.settled = false
            settleTimer.restart()

            list.currentIndex += delta
            root.window.selectIndex(list.realIndex(list.currentIndex))

            const middle = imageCount * Math.floor(repeatCount / 2)

            if (list.currentIndex < imageCount * 10) {
                list.currentIndex += middle
                list.positionViewAtIndex(list.currentIndex, ListView.Center)
            } else if (list.currentIndex > imageCount * 90) {
                list.currentIndex -= middle
                list.positionViewAtIndex(list.currentIndex, ListView.Center)
            }
        }

        

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width, visibleWidth)
        // Full parent height, not a fixed 380 - the current card's
        // real height (703) was always taller than 380, it just went
        // unclipped before. Only width needs to be tightly bounded to
        // cap the card count at 3.
        height: parent.height
        clip: true

        orientation: ListView.Horizontal
        spacing: 140

        model: imageCount * repeatCount

        interactive: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - centerCardWidth / 2
        preferredHighlightEnd: width / 2 + centerCardWidth / 2
        highlightMoveDuration: 220


        Component.onCompleted: {
            if (imageCount > 0) {
                currentIndex = imageCount * Math.floor(repeatCount / 2)
                root.window.selectIndex(0)
            }
        }

        delegate: WallpaperCardCarousel {
            required property int index

            property int actualIndex: list.realIndex(index)
            property int distance: index - list.currentIndex

            imagePath: root.window.filteredImages[actualIndex]

            isCurrent: index === list.currentIndex

            settled: list.settled
            opacity: Math.max(0, 1 - Math.abs(distance) * 0.05)

            onClicked: {
                list.currentIndex = index
                root.window.selectIndex(actualIndex)
            }

            onDoubleClicked: root.window.applySelected()
        }

        WheelHandler {
            enabled: root.visible

            onWheel: event => {
                if (event.angleDelta.y < 0)
                    list.step(1)
                else if (event.angleDelta.y > 0)
                    list.step(-1)
            }
        }

        Connections {
            target: root.window

            function onFilteredImagesChanged() {
                if (list.imageCount === 0)
                    return

                list.currentIndex =
                    list.imageCount * Math.floor(list.repeatCount / 2)

                root.window.selectIndex(0)
            }

            function onCurrentIndexChanged() {
                if (list.imageCount === 0)
                    return

                const visual = list.currentIndex
                const base = visual - list.realIndex(visual)

                list.currentIndex = base + root.window.currentIndex
            }
        }
    }

    Text {
        anchors.centerIn: parent

        visible: root.window.filteredImages.length === 0

        text: root.window.images.length === 0
              ? "No images found in this directory"
              : "No matches for \"" + root.window.searchQuery + "\""

        font.family: Colors.fontFamily
        color: Colors.fg
        opacity: 0.6
        font.pixelSize: 16
        
    }
}