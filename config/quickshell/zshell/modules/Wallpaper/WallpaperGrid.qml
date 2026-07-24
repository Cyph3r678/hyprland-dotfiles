import QtQuick
import "../../services"

// Dense multi-row grid, matching a real file-manager image browser -
// columns computed responsively, cells locked to a 16:9 aspect ratio
// (real wallpaper proportions) rather than an arbitrary box.
Item {
    id: root
    required property var window
    
    GridView {
        id: grid
        anchors.fill: parent
        anchors.topMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 24
        clip: true
        highlightMoveDuration: 150

        readonly property int columns: Math.max(3, Math.round(width / 100))
        readonly property real hSpacing: 100
        readonly property real vSpacing: 100

        cellWidth: 534
        cellHeight: 320

        model: root.window.filteredImages
        currentIndex: root.window.currentIndex

        delegate: WallpaperCardGrid {
            required property string modelData
            required property int index
            width: grid.cellWidth - grid.hSpacing
            height: grid.cellHeight - grid.vSpacing
            imagePath: modelData
            isCurrent: index === root.window.currentIndex
            onClicked: root.window.selectIndex(index)
            onDoubleClicked: root.window.applySelected()
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.window.filteredImages.length === 0
        text: root.window.images.length === 0
            ? "No images found in this directory"
            : "No matches for \"" + root.window.searchQuery + "\""
        color: Colors.fg
        font.family: Colors.fontFamily
        opacity: 0.6
        font.pixelSize: 16
    }
}