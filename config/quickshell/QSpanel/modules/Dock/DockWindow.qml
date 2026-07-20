import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"

PanelWindow {
    id: root
    property bool dockVisible: false
    property bool _mapped: false
    visible: _mapped

    // ---- pinned apps ----
    // `icon` is the filename under assets/icons/Dock/ - fill in the
    // implement remaining icon/appId/exec entries the same way.
    property var apps: [
        { name: "Terminal", appId: "kitty", exec: ["kitty"], icon: "kitty.svg" },
        { name: "Firefox", appId: "firefox", exec: ["firefox"], icon: "browser.svg" },
        { name: "Software", appId: "org.gnome.Software", exec: ["gnome-software"], icon: "gs.svg" },
        { name: "App 4", appId: "spotify", exec: ["flatpak run com.spotify.Client"], icon: "Spotify.svg" },
        { name: "App 5", appId: "VSCodium", exec: ["codium"], icon: "vs.svg" },
        { name: "App 6", appId: "org.telegram.desktop", exec: ["flatpak run org.telegram.desktop"], icon: "tg.svg" },
        { name: "App 7", appId: "com.ktechpit.whatsie", exec: ["flatpak run com.ktechpit.whatsie"], icon: "wapp.svg" },
        { name: "App 8", appId: "org.gnome.Nautilus", exec: ["nautilus"], icon: "Files.svg" },
        { name: "App 9", appId: "claude-desktop", exec: ["claude-desktop"], icon: "claude.svg" },
        { name: "App 10", appId: "dev.zed.Zed", exec: ["/home/shaurya/.local/bin/zed"], icon: "text.svg" },
        { name: "App 11", appId: "nwg-look", exec: ["nwg-look"], icon: "Settings.svg" },
        { name: "App 12", appId: "org.gnome.Calculator", exec: ["gnome-calculator"], icon: "Calculator.svg" },
    ]

    function toplevelsFor(appId) {
        if (!appId) return [];
        const target = appId.toLowerCase();
        return Hyprland.toplevels.values.filter(t => {
           
            const hyprClass = t.lastIpcObject?.class ?? "";
            if (hyprClass)
                return hyprClass.toLowerCase() === target;
           
            return (t.wayland?.appId ?? "").toLowerCase() === target;
        });
    }

    function launchOrFocus(app) {
        const matches = toplevelsFor(app.appId);
        if (matches.length > 0) {
            const addr = matches[0].address.startsWith("0x") ? matches[0].address : "0x" + matches[0].address;
            Hyprland.dispatch("focuswindow address:" + addr);
        } else if (app.exec && app.exec.length > 0 && app.exec[0] !== "") {
           
            Hyprland.dispatch("exec " + app.exec.join(" "));
        }
    }

    color: "transparent"

    readonly property real iconSize: 46
    readonly property real cardHeight: iconSize + 36
    readonly property real shadowPadding: 44
    // Reclaimed from margins.bottom below (was 12, now 0) - see the
    // top-of-response explanation. This is the most bottom-side
    // shadow room obtainable without moving the dock or pushing the
    // window past the actual screen edge; it's smaller than
    // shadowPadding (44) used on the other three sides for exactly
    // that reason.
    readonly property real bottomShadowPadding: 12

    implicitWidth: dockRow.implicitWidth + 48 + shadowPadding * 2
    implicitHeight: cardHeight + shadowPadding + bottomShadowPadding

    anchors.bottom: true
    // Was 12 - reclaimed as bottomShadowPadding above instead, with
    // background's position compensated below so the dock itself
    // doesn't move by a single pixel.
    margins.bottom: 5
    margins.top: 15

   
    exclusiveZone: cardHeight + margins.top
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:dock"

    mask: Region { item: background }

    function show() {
        _mapped = true;
        dockVisible = true;
       
        Hyprland.refreshToplevels();
    }
    function hide() { dockVisible = false; hideTimer.restart(); }
    function toggle() { dockVisible ? hide() : show(); }

    Timer {
        id: hideTimer
        interval: 220
        onTriggered: root._mapped = false
    }

    property real slideY: cardHeight

    Behavior on slideY {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
            onFinished: if (!root.dockVisible) root._mapped = false
        }
    }

    onDockVisibleChanged: slideY = dockVisible ? 0 : cardHeight

    MultiEffect {
        source: background
        anchors.fill: background
        z: -1
        shadowEnabled: root.dockVisible
        shadowColor: "#000000"
        shadowBlur: 1
    }

     MultiEffect {
        source: iconBtn
        anchors.fill: background
        z: -1
        shadowEnabled: root.dockVisible
        shadowColor: "#000000"
        shadowBlur: 1
    }

    Rectangle {
        id: background
        x: root.shadowPadding
        y: root.shadowPadding + root.slideY
        width: root.implicitWidth - root.shadowPadding * 2 + 10
        height: root.cardHeight
        radius: 25
        color: Colors.bg0
        border.color: "#161616"
        border.width: 2

        property real padding: 18
        property real verticalPadding: 12
        property real hoverX: -1

        RowLayout {
            id: dockRow
            anchors {
                fill: parent
                leftMargin: background.padding
                rightMargin: background.padding
                topMargin: background.verticalPadding
                bottomMargin: background.verticalPadding
            }
            spacing: 10

            Repeater {
                model: root.apps
                delegate: Item {
                    id: iconWrap
                    required property var modelData
                    Layout.preferredWidth: root.iconSize
                    Layout.preferredHeight: root.iconSize
                    Layout.alignment: Qt.AlignVCenter

                    readonly property var matches: root.toplevelsFor(modelData.appId)
                    readonly property bool isOpen: matches.length > 0
                    // Compares against Hyprland.activeToplevel (a single,
                    // authoritative "currently focused window" reference
                    // that Quickshell keeps live-updated, and which is
                    // explicitly null when nothing has focus) instead of
                    // each toplevel's own .activated flag. .activated can
                    // be stale leftover state from before you switched to
                    // an empty workspace - Hyprland doesn't necessarily
                    // clear it just because there's nothing left to give
                    // focus to on the new workspace. This way, if nothing
                    // is actually focused, activeToplevel is null, and
                    // nothing matches it - every icon correctly reverts
                    // to the inactive state.
                    readonly property bool isFocused: matches.some(t => t === Hyprland.activeToplevel)

                    // Restored - referenced by scale: iconWrap.magnification
                    // below but wasn't actually declared in the pasted
                    // file (looks like it got dropped during editing).
                    readonly property real iconCenterX: dockRow.x + x + width / 2
                    readonly property real distance: background.hoverX < 0 ? 9999 : Math.abs(iconCenterX - background.hoverX)
                    readonly property real magnification: {
                        if (background.hoverX < 0) return 1.0
                        const t = Math.max(0, 1 - distance / 90)
                        return 1.0 + 0.35 * t * t
                    }

                    // Icons
                    Rectangle {
                        id: iconBtn
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        radius: 15
                        color: modelData.icon ? "transparent" : "#ffffff"
                        scale: iconWrap.magnification
                        transformOrigin: Item.Bottom

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        Image {
                            visible: modelData.icon !== ""
                            anchors.centerIn: parent
                            source: modelData.icon ? Qt.resolvedUrl("../../assets/icons/Dock/" + modelData.icon) : ""
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize.width: root.iconSize * 2
                            sourceSize.height: root.iconSize * 2
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.launchOrFocus(iconWrap.modelData)
                        }
                    }

                    // Overlay Indicator
                    Rectangle {
                        visible: iconWrap.isOpen
                        width: iconWrap.isFocused ? 20 : 14
                        height: 4
                        radius: 2
                        color: iconWrap.isFocused ? Colors.fg : Colors.fg
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.iconSize + 3
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: root.iconSize - 6
                Layout.alignment: Qt.AlignVCenter
                radius: 20
                color: Colors.bg2
            }

            // Launcher
            Item {
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    id: drawerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch("exec walker")

                    Rectangle {
                        id: drawerBtn
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        radius: 20
                        border.color: Colors.purple
                        border.width: drawerArea.containsMouse ? 2 : 0

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/Dock/launcher.svg")
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize.width: 56
                            sourceSize.height: 56
                        }
                    }
                }
            }
        }

       
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            z: -1
            onPositionChanged: background.hoverX = mouse.x
            onExited: background.hoverX = -1
        }
    }
}