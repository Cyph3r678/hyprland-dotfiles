import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"
import "."

// Left-edge widgets panel. Manually toggled (like QuickSettingsPanel),
// not auto-hide. shell.qml's IPC "widgets" target calls
// toggle()/show()/hide().
PanelWindow {
    id: panel

    // State lives here rather than as plain properties on the
    // window, specifically so it survives a Quickshell config reload
    // (hot-reload on save, `qs ipc call ... reload`, etc). Without
    // this, a reload while the panel happened to be open/animating
    // could leave a stale copy of the old window behind alongside a
    // fresh one from the reload - which looks exactly like "two
    // windows, one stuck and unresponsive" - since Quickshell's
    // window-reuse-across-reload machinery keys off state like this
    // to know it's still looking at the *same* logical window.
    PersistentProperties {
        id: persist
        reloadableId: "qspanel-widgets-window"

        property bool panelVisible: false
        // 0 = hidden (shrunk down, invisible), 1 = fully open. Drives
        // both scale and opacity on `background` below - see there
        // for why scale (not position) is what's animating now.
        property real openProgress: 0

        Behavior on openProgress {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.05 // just enough pop to feel alive
                                        // without the pronounced bounce
                                        // the old slide-in had
            }
        }
    }

    // Ordinary reactive binding, not a one-shot assignment - stays
    // true for the whole close animation and flips false right as it
    // settles, with no callback/timing logic needed.
    visible: persist.openProgress > 0.001

    color: "transparent"

    readonly property real cardWidth: 660
    readonly property real cardHeight: content.implicitHeight + Colors.panelPadding * 2
    // Full shadow room on the right/bottom (unanchored sides - free
    // to extend as far as we like). Top/left are anchored to the
    // actual screen edges, so their bleed room is capped at whatever
    // margins.top/left used to be (16 each) - see edgeShadowPadding
    // below. Reclaimed from the margins rather than left as an
    // external gap, so the card's on-screen position doesn't move.
    readonly property real shadowPadding: 64
    readonly property real edgeShadowPadding: 16

    implicitWidth: cardWidth + shadowPadding + edgeShadowPadding
    implicitHeight: cardHeight + shadowPadding + edgeShadowPadding

    anchors {
        top: true
        left: true
    }

    margins {
        // Was 16/16 - reclaimed as edgeShadowPadding above instead,
        // with cardWrapper's position compensated below so the panel
        // doesn't move by a single pixel.
        top: 0
        left: 0
    }

    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:widgets"

    mask: Region {
        x: panel.edgeShadowPadding
        y: panel.edgeShadowPadding
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
        // Top/left padding is only edgeShadowPadding (16) - reclaimed
        // from margins.top/left, the most available without moving
        // the panel or pushing it past the actual screen edge.
        // Right/bottom keep the full shadowPadding (64) since those
        // sides were never anchored/constrained to begin with.
        x: panel.edgeShadowPadding
        y: panel.edgeShadowPadding
        width: panel.cardWidth
        height: panel.cardHeight

        // Grows from that same top-left point - reads as "emerging
        // from" the module instead of flying in from off-screen. The
        // shadow (MultiEffect below) and the card (`background`) both
        // live inside this wrapper and share this transform, so they
        // scale/fade in lockstep - they used to be siblings with the
        // shadow tracking `background`'s *unscaled* bounds, which
        // left it sitting at full size for the whole animation
        // instead of growing along with the card.
        transformOrigin: Item.TopLeft
        scale: 0.4 + persist.openProgress * 0.6 // 0.4 -> 1.0
        opacity: persist.openProgress

        MultiEffect {
            source: background
            anchors.fill: background
            z: -1
            autoPaddingEnabled: true
            // Tied to panelVisible, not just true - see QuickSettingsPanel.qml
            // / OsdWindow.qml for why an always-on shadow leaks into view
            // once the card has slid fully off-screen.
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
            radius: Colors.radiusOuter
            color: Colors.bg0
            clip: true // last line of defense: if a card's height is ever
                        // wrong again, this contains the damage to "looks
                        // slightly off" instead of "text on the desktop"

            RowLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Colors.panelPadding
                spacing: Colors.gapLg

                // Explicit pixel widths for BOTH columns - no Layout.fillWidth
                // anywhere in this split. This is the one genuinely new
                // layout pattern in the whole project (every other panel
                // here is a single column) - mixing a fixed-width sibling
                // with a fillWidth sibling in the same RowLayout is exactly
                // the kind of ambiguous constraint that can make one
                // collapse to near-zero width instead of behaving as
                // expected, which matches the squished-calendar symptom far
                // better than anything inside CalendarCard itself.
                readonly property real leftColWidth: 240
                readonly property real calendarColWidth: width - leftColWidth - spacing

                ColumnLayout {
                    Layout.preferredWidth: content.leftColWidth
                    Layout.maximumWidth: content.leftColWidth
                    Layout.fillHeight: true
                    spacing: Colors.gapLg

                    ClockCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                    }

                    RemindersCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                CalendarCard {
                    Layout.preferredWidth: content.calendarColWidth
                    Layout.maximumWidth: content.calendarColWidth
                    Layout.fillHeight: true
                }
            }
        }
    }
}