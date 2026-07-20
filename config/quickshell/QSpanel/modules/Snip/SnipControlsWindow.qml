import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../services"

// Fixed at the bottom-center of the screen at all times - doesn't
// track the selection's position, unlike an earlier version of this.
// Always mapped whenever the snip tool itself is open, whether you're
// still adjusting a selection or actively recording.
PanelWindow {
    id: controlsWindow

    required property var window // SnipWindow - all state/functions live there

    visible: window.panelVisible
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 40
    implicitHeight: 80

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Excluded from screencopy entirely - this (plus staying small,
    // rather than fullscreen) is what actually keeps this bar out of
    // your recordings, since it stays mapped and visible the whole
    // time recording is live. Requires a matching Hyprland layerrule
    // - see the note at the top of SnipWindow.qml. Screenshots don't
    // rely on this at all: SnipWindow.takeScreenshot() hides this
    // window too (visible is bound to window.panelVisible) before
    // calling grim, which is simpler and has no overlap edge cases.
    WlrLayershell.namespace: "qspanel:snip-controls"

    mask: Region {
        x: (controlsWindow.width - pill.width) / 2
        y: (controlsWindow.height - pill.height) / 2
        width: pill.width
        height: pill.height
    }

    property url ssIcon: Qt.resolvedUrl("../../assets/icons/screencapture/ss.svg")
    property url recorderIcon: Qt.resolvedUrl("../../assets/icons/screencapture/recorder.svg")
    property url fullscreenIcon: Qt.resolvedUrl("../../assets/icons/screencapture/fullscreen.svg")
    property url clickIcon: Qt.resolvedUrl("../../assets/icons/screencapture/click.svg")

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: pillRow.implicitWidth + 20
        height: 64
        radius: 32
        color: Colors.bg1

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 10

            // ---- mode toggle: screenshot / recording ----
            Repeater {
                model: [
                    { mode: false, icon: controlsWindow.ssIcon },
                    { mode: true,  icon: controlsWindow.recorderIcon }
                ]

                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 14
                    visible: !controlsWindow.window.recordingActive
                    color: Colors.bg2
                    opacity: controlsWindow.window.recordingMode === modelData.mode ? 1.0 : 0.55

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    Image {
                        anchors.centerIn: parent
                        source: parent.modelData.icon
                        width: 20
                        height: 20
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: controlsWindow.window.recordingMode = parent.modelData.mode
                    }
                }
            }

            // ---- fullscreen-selection toggle ----
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 14
                visible: !controlsWindow.window.recordingActive
                color: Colors.bg2
                opacity: controlsWindow.window.isFullscreenSel ? 1.0 : 0.55

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Image {
                    anchors.centerIn: parent
                    source: controlsWindow.fullscreenIcon
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const w = controlsWindow.window;
                        if (!w.isFullscreenSel) {
                            w.storedSel = { x: w.selX, y: w.selY, w: w.selW, h: w.selH };
                            w.selX = 0;
                            w.selY = 0;
                            w.selW = w.width;
                            w.selH = w.height;
                            w.isFullscreenSel = true;
                        } else if (w.storedSel) {
                            w.selX = w.storedSel.x;
                            w.selY = w.storedSel.y;
                            w.selW = w.storedSel.w;
                            w.selH = w.storedSel.h;
                            w.isFullscreenSel = false;
                        }
                    }
                }
            }

            // ---- capture button ----
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 22
                color: Colors.bg2
                opacity: (controlsWindow.window.hasSelection || controlsWindow.window.recordingActive) ? 1.0 : 0.4

                Image {
                    anchors.centerIn: parent
                    source: controlsWindow.clickIcon
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: controlsWindow.window.hasSelection
                        || (controlsWindow.window.recordingActive && controlsWindow.window.recordingPaused)
                    onClicked: {
                        const w = controlsWindow.window;
                        if (w.recordingActive && w.recordingPaused)
                            w.stopAndSave();
                        else if (!w.recordingActive)
                            w.startCapture();
                    }
                }
            }

            // ---- recording-only: elapsed timer ----
            Rectangle {
                visible: controlsWindow.window.recordingActive
                Layout.preferredWidth: timeText.implicitWidth + 24
                Layout.preferredHeight: 44
                radius: 14
                color: Colors.bg2

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: {
                        const w = controlsWindow.window;
                        const m = Math.floor(w.elapsedSeconds / 60);
                        const s = w.elapsedSeconds % 60;
                        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
                    }
                    color: Colors.fg
                    font.pixelSize: 14
                }
            }

            // ---- recording-only: pause/resume, built from plain
            // rectangles (no SVGs needed) ----
            Rectangle {
                visible: controlsWindow.window.recordingActive
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 14
                color: controlsWindow.window.recordingPaused ? Colors.bg2 : "#ff4d5e"

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: controlsWindow.window.recordingPaused

                    Rectangle { width: 5; height: 16; radius: 2; color: Colors.fg }
                    Rectangle { width: 5; height: 16; radius: 2; color: Colors.fg }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: controlsWindow.window.togglePause()
                }
            }
        }
    }
}