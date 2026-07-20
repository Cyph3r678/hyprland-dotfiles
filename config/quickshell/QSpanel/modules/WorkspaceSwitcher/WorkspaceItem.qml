pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../services"

Item {
    id: root

    // Which axis the enclosing ListView is scrolling along right now.
    // Read straight off the view rather than threading a property
    // down, so this stays correct no matter who toggles it.
    readonly property bool isVertical: root.ListView.view
        ? root.ListView.view.orientation === ListView.Vertical
        : false

    // ListView only manages the position along its scroll axis - the
    // cross-axis position is left up to us and defaults to 0 (i.e.
    // top-left aligned) if unset. Center on whichever axis the view
    // isn't controlling, so cards stay centered in both orientations.
    anchors.verticalCenter: (!root.isVertical && parent) ? parent.verticalCenter : undefined
    anchors.horizontalCenter: (root.isVertical && parent) ? parent.horizontalCenter : undefined

    required property int index
    readonly property int wsId: root.index + 1
    // Resolved lazily: null for workspaces that don't exist yet
    // (empty, never focused). That's expected, not an error.
    readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === root.wsId) || null

    // ListView attaches this to every delegate root item for free.
    readonly property bool isCurrent: ListView.isCurrentItem

    // Reference to WorkspaceSwitcherPanel, set from its delegate - lets
    // window thumbnails below reach up to shared drag/selection state
    // and the drag ghost, which live at the panel level rather than
    // being duplicated per-card.
    property var switcher: null

    // True while a drag is hovering over this specific card. Drives
    // the drop-target highlight below.
    property bool isDropTarget: false

    readonly property var monitor: root.workspace ? root.workspace.monitor : null
    // For workspaces that don't exist yet we still want a sensible
    // monitor to preview - fall back to whatever's currently focused.
    readonly property var previewMonitor: root.monitor || Hyprland.focusedMonitor || null
    // Bridge from Hyprland's monitor object to Quickshell's own
    // screen object, which is what ScreencopyView actually wants for
    // whole-output capture.
    readonly property var previewScreen: root.previewMonitor
        ? Quickshell.screens.find(s => s.name === root.previewMonitor.name) || null
        : null
    // Real (scale-corrected) monitor resolution, used to map window
    // geometry from Hyprland's absolute layout space into card-local
    // pixels.
    readonly property real monRealWidth: root.monitor ? root.monitor.width / root.monitor.scale : 1920
    readonly property real previewScale: root.monRealWidth > 0 ? card.width / root.monRealWidth : 1
    readonly property int windowCount: (root.workspace && root.workspace.toplevels) ? root.workspace.toplevels.values.length : 0

    // Optional static fallback image, only used if a live screen
    // capture isn't available for some reason (e.g. no monitor could
    // be resolved). Leave unset to just fall back to the plain card.
    property url emptyImageSource: ""

    // Card footprint. This stays landscape (wider than tall) no
    // matter which way the list is scrolling - only the *arrangement*
    // of cards changes with orientation, not their own shape.
    readonly property int cardWidthBase: 340
    readonly property int cardHeightBase: 200
    readonly property int mainAxisSize: root.isCurrent ? Math.round(root.cardWidthBase * 1.15) : Math.round(root.cardWidthBase * 0.85)
    readonly property int crossAxisSize: root.isCurrent ? Math.round(root.cardHeightBase * 1.15) : Math.round(root.cardHeightBase * 0.85)

    // We resize the item for real (rather than applying a `scale`
    // transform) so the rounded corners get rasterized fresh at their
    // actual on-screen size - scaling a pre-rendered rounded-rect
    // mask up is what caused jagged/blocky border edges.
    implicitWidth: root.mainAxisSize
    implicitHeight: root.crossAxisSize
    Behavior on implicitWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Cards no longer dim when unselected - only size/border convey
    // selection now.
    opacity: 1

    // How far the visible card sits inset from the item's own
    // (animated) bounds - gives the shadow room to breathe and a
    // little gap between neighboring cards.
    readonly property int cardMargin: 8

    // Plain, cheap-to-render background: this is what actually casts
    // the shadow. Kept separate from `card` below (which holds the
    // live previews) so the shadow effect isn't re-rendering video
    // content every frame.
    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: root.cardMargin
        radius: 30
        color: "#232323"
    }

    MultiEffect {
        source: background
        anchors.fill: background
        z: -1
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "#000000"
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowBlur: 1
        shadowOpacity: 1.0
    }

    ClippingRectangle {
        id: card
        anchors.fill: background
        anchors.margins: root.cardMargin
        radius: 20
        color: "#161616"
        border.width: root.isCurrent ? 4 : 0
        border.color: Colors.blue
        antialiasing: true

        // For workspaces with no windows, show the monitor's live
        // output instead (in practice: whatever's on that monitor
        // right now, i.e. the wallpaper if nothing's focused there).
        // Hyprland doesn't keep a separate composited buffer per
        // workspace, so this reflects the monitor, not this specific
        // workspace, if it happens to not be the one currently shown.
        ScreencopyView {
            anchors.margins: -6
            anchors.fill: parent
            visible: root.windowCount === 0 && root.previewScreen !== null
            captureSource: root.previewScreen
            live: root.isCurrent
        }

        // Last-resort fallback if no monitor could be resolved at
        // all (shouldn't normally happen). Leave emptyImageSource
        // unset to just show the plain card in that case.
        Image {
            anchors.fill: parent
            visible: root.windowCount === 0 && root.previewScreen === null && root.emptyImageSource != ""
            source: root.emptyImageSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }

        // One live thumbnail per window on this workspace, positioned
        // and scaled to match that window's real position/size on its
        // monitor. Each is also individually selectable (Ctrl+click)
        // and draggable to another workspace's card - see the
        // MouseArea inside for how that works.
        Repeater {
            model: root.workspace ? root.workspace.toplevels : null

            Item {
                id: winProxy
                required property HyprlandToplevel modelData

                // IMPORTANT: ScreencopyView below wants the underlying
                // Wayland toplevel handle, not the HyprlandToplevel
                // wrapper - modelData.wayland, not modelData itself.
                readonly property string address: modelData.lastIpcObject.address || ""
                readonly property string winTitle: modelData.lastIpcObject.title
                    || modelData.lastIpcObject.class || "Window"

                x: (root.monitor && modelData.lastIpcObject.at)
                   ? (modelData.lastIpcObject.at[0] - root.monitor.x) * root.previewScale
                   : 0
                y: (root.monitor && modelData.lastIpcObject.at)
                   ? (modelData.lastIpcObject.at[1] - root.monitor.y) * root.previewScale
                   : 0
                width: modelData.lastIpcObject.size
                       ? modelData.lastIpcObject.size[0] * root.previewScale
                       : 0
                height: modelData.lastIpcObject.size
                        ? modelData.lastIpcObject.size[1] * root.previewScale
                        : 0

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: winProxy.modelData.wayland
                    live: true
                }

                // Selection outline - visible for every window that's
                // part of the current multi-select set, regardless of
                // which card it's sitting in.
                Rectangle {
                    anchors.fill: parent
                    visible: root.switcher ? root.switcher.isSelected(winProxy.address) : false
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.blue
                }

                MouseArea {
                    id: winArea
                    anchors.fill: parent
                    preventStealing: true

                    property point pressPos: Qt.point(0, 0)
                    property bool dragging: false

                    onPressed: mouse => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        dragging = false;
                    }

                    onPositionChanged: mouse => {
                        if (!pressed || !root.switcher)
                            return;
                        const dx = mouse.x - pressPos.x;
                        const dy = mouse.y - pressPos.y;
                        if (!dragging && Math.hypot(dx, dy) > 8) {
                            dragging = true;
                            const p = winArea.mapToItem(root.switcher, mouse.x, mouse.y);
                            root.switcher.beginWindowDrag(winProxy.address, winProxy.winTitle, p.x, p.y);
                        }
                        if (dragging) {
                            const p = winArea.mapToItem(root.switcher, mouse.x, mouse.y);
                            root.switcher.updateWindowDrag(p.x, p.y);
                        }
                    }

                    onReleased: mouse => {
                        if (dragging) {
                            root.switcher.endWindowDrag();
                            dragging = false;
                            return;
                        }
                        if (root.switcher && (mouse.modifiers & Qt.ControlModifier)) {
                            root.switcher.toggleSelected(winProxy.address);
                            return;
                        }
                        // Plain click, no drag, no Ctrl: behaves like
                        // clicking anywhere else on the card.
                        root.ListView.view.currentIndex = root.index;
                        Hyprland.dispatch("workspace " + root.wsId);
                    }
                }
            }
        }

        // Drop target for dragged window(s) from any other card
        // (including this one, though dropping back onto its own
        // workspace is just a no-op dispatch).
        DropArea {
            anchors.fill: parent
            keys: ["hyprland-window"]
            onEntered: root.isDropTarget = true
            onExited: root.isDropTarget = false
            onDropped: drop => {
                const addrs = (drop.source && drop.source.draggedAddresses) ? drop.source.draggedAddresses : [];
                for (const addr of addrs) {
                    if (addr)
                        Hyprland.dispatch("movetoworkspacesilent " + root.wsId + ",address:" + addr);
                }
                root.isDropTarget = false;
                drop.accept();
            }
        }
    }

    Rectangle {
        id: fg
        anchors.fill: parent
        anchors.margins: 20
        border.width: (root.isCurrent || root.isDropTarget) ? 6 : 0
        border.color: root.isDropTarget ? Colors.green : Colors.bg2
        radius: 18
        color: "transparent"
    }

    // Clicking a card selects it and switches straight to it. Works
    // even for workspaces Hyprland hasn't created yet.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.ListView.view.currentIndex = root.index;
            Hyprland.dispatch("workspace " + root.wsId);
        }
    }
}