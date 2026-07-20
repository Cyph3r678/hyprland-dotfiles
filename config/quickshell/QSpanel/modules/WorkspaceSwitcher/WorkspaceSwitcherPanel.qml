import QtQuick
import Quickshell.Hyprland
import "../../services"
import "."

// Everything the switcher shows, minus the window/layer-shell plumbing
// (that lives in WorkspaceSwitcherWindow.qml). Kept separate so it's
// easy to reuse or preview standalone.
Item {
    id: root

    // WorkspaceSwitcherWindow listens for this to hide itself.
    signal requestClose()

    // How many workspace slots to show, regardless of whether each
    // one currently has anything on it (or exists yet as far as
    // Hyprland is concerned). Bump this if you use more than 10
    // workspaces.
    property int workspaceCount: 10

    // Shown inside any card whose workspace has no windows. Leave
    // empty for a plain dark card instead. Set this from
    // WorkspaceSwitcherWindow (which forwards it from shell.qml).
    property url emptyWorkspaceImage: ""

    // Purely visual - Hyprland has no notion of "workspace alignment"
    // (workspaces aren't spatial, only windows within them are), so
    // this only flips how *this switcher* lays its own cards out.
    // Toggled by the button in the top-right corner.
    property bool verticalLayout: false

    // The carousel strip needs room, perpendicular to its scroll
    // direction, for whatever the largest (selected) card measures on
    // that axis. Cards always stay landscape (~340x200 base), so
    // horizontal scrolling needs height-room and vertical scrolling
    // needs width-room - these numbers come from WorkspaceItem's own
    // cardWidthBase/cardHeightBase at 1.15x, plus a little padding.
    readonly property int horizontalCrossAxisSize: 260 // fits expanded height (~230)
    readonly property int verticalCrossAxisSize: 420   // fits expanded width (~391)
    // Half of the expanded card's size along the scroll axis, used to
    // center the current item in the highlight range.
    readonly property int highlightHalfExtent: root.verticalLayout ? 115 : 170

    // Dimmed backdrop. If you want a real blur (not just a dark
    // scrim) add a Hyprland layerrule matching this window's
    // namespace - see the README.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35

        MouseArea {
            // Click anywhere outside the cards to dismiss.
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    ListView {
        id: list
        anchors.centerIn: parent
        width: root.verticalLayout ? root.verticalCrossAxisSize : parent.width
        height: root.verticalLayout ? parent.height : root.horizontalCrossAxisSize

        orientation: root.verticalLayout ? ListView.Vertical : ListView.Horizontal
        spacing: 40
        // Plain integer model: card N always exists for N in
        // [0, workspaceCount), whether or not Hyprland has ever
        // created workspace N+1. WorkspaceItem resolves the real
        // HyprlandWorkspace (or null) itself.
        model: root.workspaceCount
        delegate: WorkspaceItem {
            emptyImageSource: root.emptyWorkspaceImage
            switcher: root
        }

        // No drag-scrolling - selection only moves via wheel, arrow
        // keys, or clicking a card, which keeps it predictable.
        interactive: false
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (root.verticalLayout ? height : width) / 2 - root.highlightHalfExtent
        preferredHighlightEnd: (root.verticalLayout ? height : width) / 2 + root.highlightHalfExtent
        highlightMoveDuration: 220

        focus: true

        Keys.onLeftPressed: if (!root.verticalLayout) currentIndex = Math.max(0, currentIndex - 1)
        Keys.onRightPressed: if (!root.verticalLayout) currentIndex = Math.min(count - 1, currentIndex + 1)
        Keys.onUpPressed: if (root.verticalLayout) currentIndex = Math.max(0, currentIndex - 1)
        Keys.onDownPressed: if (root.verticalLayout) currentIndex = Math.min(count - 1, currentIndex + 1)
        Keys.onReturnPressed: root.commit()
        Keys.onEnterPressed: root.commit()
        Keys.onEscapePressed: root.requestClose()
    }

    // Declared on root (which fills the whole screen), not inside the
    // ListView, so scrolling works no matter where the mouse is -
    // not just when it happens to be hovering the carousel strip in
    // the middle. Scroll direction always means "next/previous" -
    // that doesn't need to change with orientation.
    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
            else if (event.angleDelta.y > 0)
                list.currentIndex = Math.max(0, list.currentIndex - 1);
        }
    }

    // Top-right toggle: flips the carousel between horizontal and
    // vertical. Shows the icon for whichever mode you'd switch *to*.
    Rectangle {
        id: layoutToggle
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        width: 40
        height: 40
        radius: 12
        color: toggleArea.containsMouse ? "#2a2a2a" : "#1c1c1c"
        border.width: 1
        border.color: "#3a3a3a"

        Text {
            anchors.centerIn: parent
            text: root.verticalLayout ? "\u21C4" : "\u21C5" // ⇄ / ⇅
            color: "#ffffff"
            font.pixelSize: 18
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.verticalLayout = !root.verticalLayout
        }
    }

    // ---- Window drag-and-drop between cards ----
    //
    // Multi-select: Ctrl+click a window thumbnail (in WorkspaceItem)
    // to add/remove it from `selectedAddresses`. Dragging any window
    // that's part of the current selection drags the whole set
    // together; dragging a window that isn't selected just drags that
    // one window on its own.
    //
    // The drag itself is a lightweight ghost proxy (not the live
    // thumbnail), parented here at the panel root so it's never
    // subject to any card's clipping as it crosses between cards.
    // Standard Qt Quick Drag/DropArea handles the actual drop
    // detection - each WorkspaceItem has its own DropArea reading
    // `drop.source.draggedAddresses` off this ghost.
    property var selectedAddresses: []

    function isSelected(address) {
        return root.selectedAddresses.indexOf(address) >= 0;
    }

    function toggleSelected(address) {
        const updated = root.selectedAddresses.slice();
        const idx = updated.indexOf(address);
        if (idx >= 0)
            updated.splice(idx, 1);
        else
            updated.push(address);
        root.selectedAddresses = updated;
    }

    function clearSelected() {
        root.selectedAddresses = [];
    }

    function beginWindowDrag(address, label, panelX, panelY) {
        const addrs = (root.selectedAddresses.length > 0 && root.isSelected(address))
            ? root.selectedAddresses.slice()
            : [address];
        dragGhost.draggedAddresses = addrs;
        dragGhost.draggedLabel = addrs.length > 1 ? (addrs.length + " windows") : label;
        dragGhost.x = panelX - dragGhost.width / 2;
        dragGhost.y = panelY - dragGhost.height / 2;
        dragGhost.Drag.active = true;
    }

    function updateWindowDrag(panelX, panelY) {
        dragGhost.x = panelX - dragGhost.width / 2;
        dragGhost.y = panelY - dragGhost.height / 2;
    }

    function endWindowDrag() {
        if (dragGhost.Drag.active)
            dragGhost.Drag.drop();
        dragGhost.Drag.active = false;
        root.clearSelected();
    }

    Rectangle {
        id: dragGhost
        z: 1000
        visible: Drag.active
        width: 180
        height: 52
        radius: 14
        color: "#e01c1c1c"
        border.width: 2
        border.color: Colors.blue

        property var draggedAddresses: []
        property string draggedLabel: ""

        Drag.active: false
        Drag.keys: ["hyprland-window"]
        Drag.hotSpot: Qt.point(width / 2, height / 2)

        Text {
            anchors.centerIn: parent
            anchors.margins: 12
            width: parent.width - 24
            text: dragGhost.draggedLabel
            color: "#ffffff"
            font.pixelSize: 13
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }


    function commit() {
        const item = list.currentItem;
        if (item)
            Hyprland.dispatch("workspace " + item.wsId);
        root.requestClose();
    }

    // Called by the window right before it becomes visible: re-center
    // the carousel on whichever workspace is actually focused right
    // now, and grab keyboard focus so arrow keys work immediately.
    function activate() {
        const focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, focusedId - 1));
        list.forceActiveFocus();
    }
}