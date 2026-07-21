import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "."

// Fullscreen overlay hosting the workspace switcher. Exposes
// toggle()/show()/hide() so it wires into shell.qml exactly like
// DockWindow, PowerMenuWindow, etc.:
//
//   WorkspaceSwitcherWindow { id: workspaceSwitcher }
//
//   IpcHandler {
//       target: "workspaceswitcher"
//       function toggle(): void { workspaceSwitcher.toggle(); }
//       function show(): void { workspaceSwitcher.show(); }
//       function hide(): void { workspaceSwitcher.hide(); }
//   }
PanelWindow {
    id: window

    function toggle(): void { window.visible = !window.visible; }
    function show(): void { window.visible = true; }
    function hide(): void { window.visible = false; }

    // Set this to show a fallback image inside cards for workspaces
    // with no windows, e.g.:
    //   WorkspaceSwitcherWindow {
    //       id: workspaceSwitcher
    //       emptyWorkspaceImage: "file:///home/you/Pictures/empty-ws.png"
    //   }
    property url emptyWorkspaceImage: ""

    visible: false
    color: "transparent"

    // Takes keyboard focus while open so arrow keys / Enter / Escape
    // reach the ListView. Hyprland gives it back to whatever was
    // focused before as soon as this becomes invisible again.
    focusable: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // -1 is a special wlr-layer-shell value meaning "ignore other
    // surfaces' exclusive zone reservations when positioning me" -
    // as opposed to 0 (respect them, shrink to fit) or a positive
    // number (reserve that much space for myself, like DockWindow
    // does). This is what lets the switcher render truly fullscreen,
    // overlapping the dock's reserved strip instead of being squeezed
    // to avoid it.
    exclusiveZone: -1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qspanel:workspaceswitcher"

    WorkspaceSwitcherPanel {
        id: panel
        anchors.fill: parent
        emptyWorkspaceImage: window.emptyWorkspaceImage
        onRequestClose: window.hide()
    }

    onVisibleChanged: if (visible) {
        // Workspace/monitor/toplevel state can go stale between
        // opens (moved windows, closed apps, monitor changes) since
        // not every change fires an event Quickshell listens for.
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
        panel.activate();
    }
}