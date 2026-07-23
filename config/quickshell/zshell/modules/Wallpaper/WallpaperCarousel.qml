import QtQuick
import "../../services"

Item {
    id: root
    required property var window

    ListView {
        id: list
        anchors.centerIn: parent
        width: parent.width
        height: 380

        orientation: ListView.Horizontal
        spacing: 40
        model: root.window.filteredImages
        currentIndex: root.window.currentIndex

        interactive: false
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 170
        preferredHighlightEnd: width / 2 + 170
        highlightMoveDuration: 220

        delegate: WallpaperCardCarousel {
            required property string modelData
            required property int index
            imagePath: modelData
            isCurrent: ListView.isCurrentItem
            onClicked: root.window.selectIndex(index)
            onDoubleClicked: root.window.applySelected()
        }

        WheelHandler {
            enabled: root.visible
            onWheel: event => {
                if (event.angleDelta.y < 0)
                    root.window.selectIndex(root.window.currentIndex + 1);
                else if (event.angleDelta.y > 0)
                    root.window.selectIndex(root.window.currentIndex - 1);
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