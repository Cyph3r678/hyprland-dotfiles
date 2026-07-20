import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../services"
import "."

// Top-center battery status popup. Toggled via shell.qml's IPC
// "battery" target (toggle()/show()/hide()):
//
//   BatteryWindow { id: batteryWindow }
//
//   IpcHandler {
//       target: "battery"
//       function toggle(): void { batteryWindow.toggle(); }
//       function show(): void { batteryWindow.show(); }
//       function hide(): void { batteryWindow.hide(); }
//   }
PanelWindow {
    id: panel

    // State lives here rather than as plain properties on the
    // window, specifically so it survives a Quickshell config reload
    // (hot-reload on save, `qs ipc call ... reload`, etc).
    PersistentProperties {
        id: persist
        reloadableId: "qspanel-battery-window"

        property bool panelVisible: false
        // 0 = hidden (shrunk down, invisible), 1 = fully open.
        property real openProgress: 0

        Behavior on openProgress {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.4 // noticeably poppier than the
                                       // widgets panel - this one's
                                       // meant to feel like it's
                                       // popping out
            }
        }
    }

    // Ordinary reactive binding, not a one-shot assignment - stays
    // true for the whole close animation and flips false right as it
    // settles, with no callback/timing logic needed.
    visible: persist.openProgress > 0.001

    color: "transparent"

    // Gap between the very top of the screen (i.e. your waybar) and
    // the card. Tune to sit just under the bar.
    readonly property real topGap: 12
    readonly property real cardWidth: 460
    readonly property real cardHeight: card.implicitHeight + Colors.panelPadding * 2
    readonly property real shadowPadding: 48

    // Tightly sized around the card - NOT anchored left+right to span
    // the full screen. A large, mostly-transparent surface with only
    // a small region rapidly rescaling inside it is a rough edge for
    // compositor damage-tracking on some setups, and can show a
    // stale/duplicate frame of the previous state while the small
    // region is still mid-animation - which looks exactly like "two
    // windows" without there actually being two windows. Keeping the
    // whole surface small and tightly matched to the card (same
    // approach as WidgetsWindow, which doesn't have this issue)
    // avoids that entirely.
    implicitWidth: cardWidth + shadowPadding
    implicitHeight: cardHeight + topGap + shadowPadding

    anchors {
        top: true
        left: true
    }

     margins {
        top: 4
    }

    // No native "center horizontally" anchor on PanelWindow, so this
    // computes a left margin that centers the (now tightly-sized)
    // window on the screen instead.
    readonly property real screenWidth: panel.screen ? panel.screen.width : 1920
    margins.left: Math.round((screenWidth - implicitWidth) / 2)

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "qspanel:battery"

    mask: Region {
        x: panel.shadowPadding / 2
        y: panel.topGap
        width: persist.openProgress > 0.01 ? panel.cardWidth : 0
        height: persist.openProgress > 0.01 ? panel.cardHeight : 0
    }

    function show() {
        persist.panelVisible = true;
        persist.openProgress = 1;
    }

    function hide() {
        persist.panelVisible = false;
        persist.openProgress = 0;
    }

    function toggle() {
        if (persist.panelVisible)
            hide();
        else
            show();
    }

    Item {
        id: cardWrapper
        x: panel.shadowPadding / 2
        y: panel.topGap
        width: panel.cardWidth
        height: panel.cardHeight

        // Grows from the top edge, centered horizontally - reads as
        // "dropping down and popping in" right under the bar. Both
        // the shadow and the card live inside this same wrapper and
        // share this transform, so they scale/fade in lockstep -
        // previously the shadow (MultiEffect below) tracked
        // `background`'s unscaled bounds and stayed full-size for the
        // whole animation, which looked exactly like a second,
        // stationary window sitting behind the actual (smaller,
        // still-growing) card.
        transformOrigin: Item.Top
        scale: 0.4 + persist.openProgress * 0.6
        opacity: persist.openProgress

        MultiEffect {
            source: background
            anchors.fill: background
            z: -1
            autoPaddingEnabled: true
            shadowEnabled: persist.panelVisible
            shadowColor: "#000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 1
            blurMax: 40
            shadowOpacity: 1.0
        }

       

        Rectangle {
            id: background
            anchors.fill: parent
            radius: 15
            color: Colors.bg0
            clip: true // safety net, same reasoning as the widgets card

            BatteryCard {
                id: card
                anchors.fill: parent
                anchors.margins: Colors.panelPadding
            }
        }
    }
}