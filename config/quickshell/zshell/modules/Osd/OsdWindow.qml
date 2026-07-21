import "../../services"
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland


PanelWindow {
    id: osd

    property bool _mapped: false
    readonly property real cardWidth: 320
    readonly property real cardHeight: 64
    
    readonly property real shadowPadding: 32
    
    property string kind: "brightness"
    property real value: 0 // 0.0-1.0
   
    property real slideY: cardHeight + shadowPadding
    property bool _shouldShow: false

    
    function show(newKind, newValue) {
        kind = newKind;
        value = newValue;
        _mapped = true;
        _shouldShow = true;
        slideY = 0;
        hideTimer.restart();
    }

    visible: _mapped
    color: "transparent"
    implicitWidth: cardWidth + shadowPadding * 2
    implicitHeight: cardHeight + shadowPadding * 2
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:osd"

    anchors {
        bottom: true
    }

    margins {
        bottom: 36
    }

    Timer {
        id: hideTimer

        interval: 1600
        onTriggered: {
            osd._shouldShow = false;
            osd.slideY = osd.cardHeight + osd.shadowPadding;
        }
    }

    MultiEffect {
        source: background
        anchors.fill: background
        z: -2
        autoPaddingEnabled: true
        shadowEnabled: osd._shouldShow
        shadowColor: "#000000"
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowBlur: 0.8
        blurMax: 24
        shadowOpacity: 1
    }

    Rectangle {
        id: background
        border.color: Colors.bg1
        border.width: 4  
        x: osd.shadowPadding
        y: osd.shadowPadding + osd.slideY
        width: osd.cardWidth
        height: osd.cardHeight
        radius: 20
        color: Colors.bg0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 26

            Text {
                 
                text: Math.round(osd.value * 100) + "%"
                color: Colors.fg
                font.pixelSize: 20
                font.family: Colors.fontFamily
                Layout.preferredWidth: 55
            }

            Rectangle {
                id: track

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: osd.kind === "volume" ? Colors.vol : Colors.bb
                clip: true

                Rectangle {
                    width: Math.max(track.height, track.width * osd.value)
                    height: parent.height
                    radius: 10
                    color: osd.kind === "volume" ? Colors.red : Colors.blue

                    Behavior on width {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

    Rectangle {
        id: clip

        x: osd.shadowPadding + 70
        y: osd.shadowPadding + osd.slideY + 12.5
        width: 50
        height: 40
        radius: 10
        color: Colors.bg2

        RowLayout {
            anchors.margins: 0
            spacing: 0
            y: 8


            Image {
                source: {
                    if (osd.kind === "volume")
                        return Qt.resolvedUrl(osd.value <= 0 ? "../../assets/icons/volume_muted.svg" : "../../assets/icons/volume.svg");

                    return Qt.resolvedUrl("../../assets/icons/brightness.svg");
                }
                width: 20
                height: 20
                sourceSize.width: 22
                sourceSize.height: 22
                smooth: true
                anchors.left: parent.left
                anchors.leftMargin: 13.5
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit

                MultiEffect {
                    source: background
                    anchors.fill: background
                    z: -1
                    autoPaddingEnabled: true
                    shadowEnabled: osd._shouldShow
                    shadowColor: "#73000000"
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    shadowBlur: 1
                    shadowOpacity: 1
                }

            }

        }

    }

    mask: Region {
        item: background
    }

    Behavior on slideY {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
            onFinished: {
                if (!osd._shouldShow)
                    osd._mapped = false;

            }
        }

    }

}