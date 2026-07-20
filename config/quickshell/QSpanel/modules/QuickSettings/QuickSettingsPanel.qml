import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"



PanelWindow {
    id: panel

    signal requestClose()

    // State lives here rather than as plain properties on the
    // window, specifically so it survives a Quickshell config reload
    // (hot-reload on save, `qs ipc call ... reload`, etc).
    PersistentProperties {
        id: persist
        reloadableId: "qspanel-quicksettings-window"

        property bool panelVisible: false
        // 0 = hidden (shrunk down, invisible), 1 = fully open.
        property real openProgress: 0

        Behavior on openProgress {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }
    }

    // Ordinary reactive binding, not a one-shot assignment - stays
    // true for the whole close animation and flips false right as it
    // settles, with no callback/timing logic needed.
    visible: persist.openProgress > 0.001

    // External code (e.g. shell.qml binding panelVisible to a root
    // property) still just sets this like a plain bool.
    property alias panelVisible: persist.panelVisible
    onPanelVisibleChanged: persist.openProgress = panelVisible ? 1 : 0

    color: "transparent"

    readonly property real cardWidth: 420
    readonly property real cardHeight: content.implicitHeight + Colors.panelPadding * 2
    // Full shadow room on the left/bottom (unanchored sides - free to
    // extend as far as we like). Top/right are anchored to the actual
    // screen edges, so their bleed room is capped at whatever
    // margins.top/right used to be (16 each) - see edgeShadowPadding
    // below. Reclaimed from the margins rather than left as an
    // external gap, so the card's on-screen position doesn't move.
    readonly property real shadowPadding: 64
    readonly property real edgeShadowPadding: 16

    implicitWidth: cardWidth + shadowPadding + edgeShadowPadding
    implicitHeight: cardHeight + shadowPadding + edgeShadowPadding

    anchors {
        top: true
        right: true
    }

    margins {
        // Was 16/16 - reclaimed as edgeShadowPadding above instead,
        // with cardWrapper's position compensated below so the panel
        // doesn't move by a single pixel.
        top: 0
        right: 0
    }

    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:quicksettings"

    // Explicit rect rather than `item: background` - the window stays
    // mapped through the whole close animation now (see `visible`
    // above), so this is what actually makes clicks pass through to
    // whatever's underneath while closed/mid-close, since
    // background's own geometry never changes (only its scale/opacity
    // do).
    mask: Region {
        x: panel.shadowPadding
        y: panel.edgeShadowPadding
        width: persist.openProgress > 0.01 ? panel.cardWidth : 0
        height: persist.openProgress > 0.01 ? panel.cardHeight : 0
    }

    Item {
        id: cardWrapper
        // Left padding is the full shadowPadding (unanchored side).
        // Top padding is only edgeShadowPadding (16) - reclaimed from
        // margins.top, which is the most available without moving the
        // panel or pushing it past the actual screen edge.
        x: panel.shadowPadding
        y: panel.edgeShadowPadding
        width: panel.cardWidth
        height: panel.cardHeight

        // Grows from the top-right corner - reads as "emerging from"
        // the quicksettings module up there instead of sliding in.
        // The shadow (MultiEffect below) and the card (`background`)
        // both live inside this wrapper and share this transform, so
        // they scale/fade in lockstep - as siblings, the shadow would
        // otherwise track `background`'s *unscaled* bounds and sit at
        // full size for the whole animation while the card is still
        // small, which reads as a second, stationary window behind
        // it (see WidgetsWindow.qml / BatteryWindow.qml for where
        // this exact bug showed up first).
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
            radius: Colors.radiusOuter
            color: Colors.bg0
            clip: true // safety net: contains any future sizing bug
                        // instead of letting content spill outside

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Colors.panelPadding
                spacing: Colors.gapLg

                ProfileCard {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Colors.gapLg

                    WifiTile {
                        Layout.fillWidth: true
                    }

                    BluetoothTile {
                        Layout.fillWidth: true
                    }
                }

                BrightnessSlider {
                    Layout.fillWidth: true
                }

                VolumeSlider {
                    Layout.fillWidth: true
                }

                MediaPlayerCard {
                    Layout.fillWidth: true
                }
            }
        }
    }
}