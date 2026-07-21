import QtQuick
import Quickshell
import "../../services"

// Dimming + selection only now - the control bar lives in its own
// separate, always-fixed-position window (SnipControlsWindow.qml),
// decoupled from wherever the selection happens to be.
Item {
    id: root

    required property var window // SnipWindow - all state/functions
                                  // live there, this is purely visual.

    readonly property color dimColor: "#99000000"

    // ---- dimmed backdrop: four strips around the selection, rather
    // than one big rect with a "hole" punched in it (Qt Quick has no
    // built-in inverse-mask for that without a custom shader) ----
    Rectangle { // top strip
        color: root.dimColor
        x: 0
        y: 0
        width: root.width
        height: root.window.hasSelection ? root.window.selY : root.height
    }
    Rectangle { // bottom strip
        color: root.dimColor
        visible: root.window.hasSelection
        x: 0
        y: root.window.selY + root.window.selH
        width: root.width
        height: root.height - (root.window.selY + root.window.selH)
    }
    Rectangle { // left strip
        color: root.dimColor
        visible: root.window.hasSelection
        x: 0
        y: root.window.selY
        width: root.window.selX
        height: root.window.selH
    }
    Rectangle { // right strip
        color: root.dimColor
        visible: root.window.hasSelection
        x: root.window.selX + root.window.selW
        y: root.window.selY
        width: root.width - (root.window.selX + root.window.selW)
        height: root.window.selH
    }

    // ---- creation drag: press+drag anywhere outside the current
    // selection starts a brand new one. Hold Shift to lock it square. ----
    MouseArea {
        anchors.fill: parent
        z: 0

        property point origin: Qt.point(0, 0)
        property bool creating: false

        onPressed: mouse => {
            const w = root.window;
            // Press inside the existing selection: let selectionItem's
            // own MouseArea (drag-to-move) handle it instead.
            if (w.hasSelection
                && mouse.x >= w.selX && mouse.x <= w.selX + w.selW
                && mouse.y >= w.selY && mouse.y <= w.selY + w.selH) {
                mouse.accepted = false;
                return;
            }
            origin = Qt.point(mouse.x, mouse.y);
            creating = true;
            w.hasSelection = true;
            w.isFullscreenSel = false;
            w.selX = mouse.x;
            w.selY = mouse.y;
            w.selW = 1;
            w.selH = 1;
        }

        onPositionChanged: mouse => {
            if (!creating)
                return;
            let dx = mouse.x - origin.x;
            let dy = mouse.y - origin.y;
            if (mouse.modifiers & Qt.ShiftModifier) {
                const s = Math.max(Math.abs(dx), Math.abs(dy));
                dx = dx < 0 ? -s : s;
                dy = dy < 0 ? -s : s;
            }
            const w = root.window;
            w.selX = Math.max(0, Math.min(origin.x, origin.x + dx));
            w.selY = Math.max(0, Math.min(origin.y, origin.y + dy));
            w.selW = Math.abs(dx);
            w.selH = Math.abs(dy);
        }

        onReleased: {
            creating = false;
            root.window.clampSelection();
        }
    }

    // ---- the selection itself: border only, drag-to-move, 8 resize
    // handles ----
    Item {
        id: selectionItem
        visible: root.window.hasSelection
        x: root.window.selX
        y: root.window.selY
        width: root.window.selW
        height: root.window.selH
        z: 1

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: Colors.blue
        }

        MouseArea {
            anchors.fill: parent
            drag.target: parent
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: root.width - selectionItem.width
            drag.maximumY: root.height - selectionItem.height
            onXChanged: root.window.selX = selectionItem.x
            onYChanged: root.window.selY = selectionItem.y
        }

        Repeater {
            model: [
                { key: "tl", ax: 0,   ay: 0 },   { key: "t", ax: 0.5, ay: 0 },   { key: "tr", ax: 1, ay: 0 },
                { key: "l",  ax: 0,   ay: 0.5 },                                 { key: "r",  ax: 1, ay: 0.5 },
                { key: "bl", ax: 0,   ay: 1 },   { key: "b", ax: 0.5, ay: 1 },   { key: "br", ax: 1, ay: 1 }
            ]

            Rectangle {
                required property var modelData
                width: 12
                height: 12
                radius: 6
                color: "#ffffff"
                border.width: 2
                border.color: Colors.blue
                x: selectionItem.width * modelData.ax - width / 2
                y: selectionItem.height * modelData.ay - height / 2

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 // bigger hit target than the visible dot
                    cursorShape: Qt.SizeAllCursor

                    property point pressGlobal: Qt.point(0, 0)
                    property real startX: 0
                    property real startY: 0
                    property real startW: 0
                    property real startH: 0

                    onPressed: mouse => {
                        pressGlobal = mapToItem(root, mouse.x, mouse.y);
                        startX = root.window.selX;
                        startY = root.window.selY;
                        startW = root.window.selW;
                        startH = root.window.selH;
                    }

                    onPositionChanged: mouse => {
                        const g = mapToItem(root, mouse.x, mouse.y);
                        const dx = g.x - pressGlobal.x;
                        const dy = g.y - pressGlobal.y;
                        const key = modelData.key;

                        let nx = startX, ny = startY, nw = startW, nh = startH;
                        if (key.includes("l")) { nx = startX + dx; nw = startW - dx; }
                        if (key.includes("r")) { nw = startW + dx; }
                        if (key.includes("t")) { ny = startY + dy; nh = startH - dy; }
                        if (key.includes("b")) { nh = startH + dy; }

                        const w = root.window;
                        if (nw < w.minSelSize) {
                            if (key.includes("l")) nx = startX + startW - w.minSelSize;
                            nw = w.minSelSize;
                        }
                        if (nh < w.minSelSize) {
                            if (key.includes("t")) ny = startY + startH - w.minSelSize;
                            nh = w.minSelSize;
                        }

                        w.selX = nx;
                        w.selY = ny;
                        w.selW = nw;
                        w.selH = nh;
                        w.isFullscreenSel = false;
                    }

                    onReleased: root.window.clampSelection()
                }
            }
        }
    }

    Keys.onEscapePressed: root.window.resetAndClose()
    focus: true
}