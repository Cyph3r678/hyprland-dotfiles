import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"

// The idle/selecting-phase control bar: mode toggle, fullscreen
// toggle, capture. Lives directly inside SnipWindow (not its own
// window) so its stacking order above the dimming/selection is
// guaranteed by normal QML paint order. Disappears the moment
// recording starts, along with the rest of SnipWindow - from there,
// SnipRecordingBar.qml (a genuinely separate window) takes over.
Item {
    id: root

    required property var window // SnipWindow - all state/functions live there

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 40

    implicitWidth: pill.width
    implicitHeight: pill.height

    property url ssIcon: Qt.resolvedUrl("../../assets/icons/screencapture/ss.svg")
    property url recorderIcon: Qt.resolvedUrl("../../assets/icons/screencapture/recorder.svg")
    property url fullscreenIcon: Qt.resolvedUrl("../../assets/icons/screencapture/fullscreen.svg")
    property url clickIcon: Qt.resolvedUrl("../../assets/icons/screencapture/click.svg")
    

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
    
    Rectangle {
        id: pill
        width: pillRow.implicitWidth + 20
        height: 64
        radius: 10
        color: Colors.bg1

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 10

            // ---- mode toggle: screenshot / recording ----
            Repeater {
                model: [
                    { mode: false, icon: root.ssIcon },
                    { mode: true,  icon: root.recorderIcon }
                ]

                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 14
                    color: Colors.bg2
                    opacity: root.window.recordingMode === modelData.mode ? 1.0 : 0.55

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
                        onClicked: root.window.recordingMode = parent.modelData.mode
                    }
                }
            }

            // ---- fullscreen-selection toggle ----
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 14
                color: Colors.bg2
                opacity: root.window.isFullscreenSel ? 1.0 : 0.55

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Image {
                    anchors.centerIn: parent
                    source: root.fullscreenIcon
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const w = root.window;
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
                opacity: root.window.hasSelection ? 1.0 : 0.4

                Image {
                    anchors.centerIn: parent
                    source: root.clickIcon
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.window.hasSelection
                    onClicked: root.window.startCapture()
                }
            }
        }
    }
}