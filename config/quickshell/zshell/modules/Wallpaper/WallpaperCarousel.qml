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

        function realIndex(i) {
            return ((i % imageCount) + imageCount) % imageCount
        }

        function step(delta) {
            if (imageCount === 0)
                return

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

        anchors.centerIn: parent
        width: parent.width
        height: 380

        orientation: ListView.Horizontal
        spacing: 40

        model: imageCount * repeatCount

        interactive: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 170
        preferredHighlightEnd: width / 2 + 170
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

            imagePath: root.window.filteredImages[actualIndex]

            isCurrent: index === list.currentIndex

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