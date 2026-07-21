import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../services"


Rectangle {
    id: root

    HoverHandler {
        id: cardHover
    }

   
    implicitHeight: content.implicitHeight + 36
    radius: Colors.radiusCard
    color: (cardHover.hovered || cardArea.pressed)
        ? "#232323"
        : Colors.bg1

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    border.color: Colors.blue
    border.width: cardArea.pressed ? 2 : 0

    Behavior on border.width {
        NumberAnimation { duration: 90 }
    }

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool playing: player?.isPlaying ?? false

    property bool expanded: false
    property bool _contentVisible: false

    onExpandedChanged: {
        if (expanded) {
            collapseTimer.stop();
            _contentVisible = true;
        } else {
            collapseTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: 180
        onTriggered: root._contentVisible = false
    }

    
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0)
            return "00:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // album art
            ClippingRectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: Colors.radiusTile
                color: Colors.bgX

                Image {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("../../assets/media.png")
                        width: 96
                        height: 96
                        sourceSize.width: 736
                        sourceSize.height: 736
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                }  


                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.player?.trackArtUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

            }

            // ---- title / artist / transport ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                Layout.rightMargin: 12
                Layout.minimumWidth: 120

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || "Nothing playing"
                        color: Colors.fg
                        font.pixelSize: 14
                        font.bold: false
                        font.family: Colors.fontFamily
                        elide: Text.ElideRight
                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist || ""
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                    elide: Text.ElideRight
                }


                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20

                    // previous
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 32
                        radius: 16
                         HoverHandler {
                            id: cardHover3
                           }


                        color: (cardHover3.hovered || nextArea.pressed)
                          ? "#272727"
                          : Colors.bgX

                         Behavior on color {
                           ColorAnimation {
                          duration: 120
                                }
                        }
                        opacity: prevArea.enabled ? 1.0 : 0.4
                        border.color: Colors.blue
                        border.width: prevArea.pressed ? 2 : 0
                        scale: prevArea.pressed ? 0.9 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/prev.svg")
                            width: 28
                            height: 28
                            sourceSize.width: 32
                            sourceSize.height: 32
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: root.player?.canGoPrevious ?? false
                            onClicked: root.player.previous()
                        }
                    }

                    // play/pause
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 23
                         HoverHandler {
                            id: cardHover2
                           }


                        color: (cardHover2.hovered || nextArea.pressed)
                          ? "#272727"
                          : Colors.bgX

                         Behavior on color {
                           ColorAnimation {
                          duration: 120
                                }
                        }
                        opacity: playArea.enabled ? 1.0 : 0.4
                        border.color: Colors.blue
                        border.width: playArea.pressed ? 2 : 0
                        scale: playArea.pressed ? 0.9 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: root.playing
                                ? Qt.resolvedUrl("../../assets/icons/pause.svg")
                                : Qt.resolvedUrl("../../assets/icons/play.svg")
                            width: 20
                            height: 20
                            sourceSize.width: 32
                            sourceSize.height: 32
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            enabled: root.player?.canTogglePlaying ?? false
                            onClicked: root.player.togglePlaying()
                        }
                    }

                    // next
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 32
                        radius: 16

                         HoverHandler {
                            id: cardHover1
                           }


                        color: (cardHover1.hovered || nextArea.pressed)
                          ? "#272727"
                          : Colors.bgX

                         Behavior on color {
                           ColorAnimation {
                          duration: 120
                                }
                        }
                        opacity: nextArea.enabled ? 1.0 : 0.4
                        border.color: Colors.blue
                        border.width: nextArea.pressed ? 2 : 0
                        scale: nextArea.pressed ? 0.9 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/Next.svg")
                            width: 28
                            height: 28
                            sourceSize.width: 32
                            sourceSize.height: 32
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: root.player?.canGoNext ?? false
                            onClicked: root.player.next()
                        }
                    }
                }
            }
        }

        
        Item {
            id: listWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: root._contentVisible ? listInner.implicitHeight : 0
            Layout.topMargin: root._contentVisible ? 4 : 0
            visible: root._contentVisible
            clip: true

            ColumnLayout {
                id: listInner
                width: listWrapper.width
                spacing: 6

                opacity: root.expanded ? 1 : 0
                y: root.expanded ? 0 : -10

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on y {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

               
                Rectangle {
                    id: progressTrack
                    Layout.rightMargin: 4
                    Layout.leftMargin: 4
                    Layout.fillWidth: true
                    implicitHeight: 16
                    radius: 16
                    color: Colors.bgX
                    clip: true

                    readonly property bool seekable: (root.player?.canSeek ?? false)
                        && (root.player?.positionSupported ?? false)
                        && (root.player?.lengthSupported ?? false)
                        && (root.player?.length ?? 0) > 0

                  
                    property real dragRatio: -1

                    readonly property real displayRatio: {
                        if (dragRatio >= 0)
                            return dragRatio;
                        if (!root.player || !root.player.lengthSupported || root.player.length <= 0)
                            return 0;
                        return Math.max(0, Math.min(1, root.player.position / root.player.length));
                    }

                    function seekTo(ratio) {
                        const clamped = Math.max(0, Math.min(1, ratio));
                        dragRatio = clamped;
                        if (root.player && seekable)
                            root.player.position = clamped * root.player.length;
                    }

                    Rectangle {
                        width: Math.max(0, progressTrack.width * progressTrack.displayRatio)
                        height: parent.height
                        radius: parent.radius
                        color: Colors.blue

                        Behavior on width {
                            enabled: progressTrack.dragRatio < 0
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: progressTrack.seekable
                        onPressed: mouse => progressTrack.seekTo(mouse.x / progressTrack.width)
                        onPositionChanged: mouse => {
                            if (pressed)
                                progressTrack.seekTo(mouse.x / progressTrack.width);
                        }
                        onReleased: {
                            progressTrack.dragRatio = -1;
                            if (root.player)
                                root.player.positionChanged();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.leftMargin: 8
                        Layout.topMargin: 8
                        text: root.player ? root.formatTime(root.player.position) : "00:00"
                        color: Colors.fgMuted
                        font.pixelSize: 12
                        font.family: Colors.fontFamily
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        Layout.topMargin: 8
                        Layout.rightMargin: 8
                        text: root.player && root.player.lengthSupported ? root.formatTime(root.player.length) : "00:00"
                        color: Colors.fgMuted
                        font.pixelSize: 12
                        font.family: Colors.fontFamily
                    }
                }
            }
        }
    }

    MouseArea {
        id: cardArea
        anchors.fill: parent
        z: -1
        onDoubleClicked: root.expanded = !root.expanded
    }
}