import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"

// Recording-only controls: timer, pause/resume, capture-to-stop-and-
// save. A genuinely separate window from SnipWindow (different
// namespace, different surface) - only ever mapped once SnipWindow
// has already fully unmapped itself (see window.visible there), so
// the two are never simultaneously on screen and there's no
// compositor stacking-order fight between them.
//
// Being small and fixed-bottom (not fullscreen) is what makes
// no_screen_share actually safe to use here: it excludes this
// surface's *entire* occupied region from any screencopy, so keeping
// that region small means only a small pill gets excluded from your
// recording, not the whole screen.
PanelWindow {
    id: recBar

    required property var window // SnipWindow - all state/functions live there

    visible: window.recordingActive
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 40
    implicitHeight: 80
    

    MultiEffect {
            source: pill
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

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    // None, not Exclusive - recording is meant to leave the rest of
    // your desktop (keyboard included) fully usable.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qspanel:snip-recording"

    property url clickIcon: Qt.resolvedUrl("../../assets/icons/screencapture/click.svg")

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: pillRow.implicitWidth + 20
        height: 64
        radius: 10
        color: Colors.bg1

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 10

            // ---- capture button, repurposed here as "stop and save"
            // - only actually does anything while paused, per the
            // original spec (pause first, then capture-click saves) ----
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 22
                color: Colors.bg2
                opacity: recBar.window.recordingPaused ? 1.0 : 0.4

                Image {
                    anchors.centerIn: parent
                    source: recBar.clickIcon
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: recBar.window.recordingPaused
                    onClicked: recBar.window.stopAndSave()
                }
            }

            // ---- elapsed timer ----
            Rectangle {
                Layout.preferredWidth: timeText.implicitWidth + 24
                Layout.preferredHeight: 44
                radius: 14
                color: Colors.bg2

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: {
                        const w = recBar.window;
                        const m = Math.floor(w.elapsedSeconds / 60);
                        const s = w.elapsedSeconds % 60;
                        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
                    }
                    color: Colors.fg
                    font.pixelSize: 14
                }
            }

            // ---- pause/resume, built from plain rectangles (no SVGs
            // needed) ----
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 10
                color: recBar.window.recordingPaused ? Colors.bg2 : Colors.red

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: recBar.window.recordingPaused

                    Rectangle { width: 5; height: 16; radius: 2; color: Colors.fg }
                    Rectangle { width: 5; height: 16; radius: 2; color: Colors.fg }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: recBar.window.togglePause()
                }
            }
        }
    }
}