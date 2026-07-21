import QtQuick
import QtQuick.Layouts
import "../../services"

Rectangle {
    id: root

    HoverHandler {
    id: cardHover
    }

    Layout.alignment: Qt.AlignTop
    implicitHeight: content.implicitHeight + 32
    radius: Colors.radiusCard
    color: (cardHover.hovered || cardArea.pressed)
       ? "#272727"
       : Colors.bg1

      Behavior on color {
       ColorAnimation {
        duration: 120
         }
     }
    border.color: Colors.blue
    border.width: cardArea.pressed ? 2 : 0

    property bool expanded: false
    property bool _contentVisible: false
    readonly property real maxListHeight: 3 * 44 + 2 * 6

    onExpandedChanged: {
        if (expanded) {
            BluetoothService.startScan();
            collapseTimer.stop();
            _contentVisible = true;
        } else {
            BluetoothService.stopScan();
            collapseTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: 180
        onTriggered: root._contentVisible = false
    }

    Behavior on border.width {
        NumberAnimation { duration: 90 }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Colors.radiusTile
                color: Colors.blue

                Image {
                    anchors.centerIn: parent
                    source: BluetoothService.connectedName.length > 0
                        ? Qt.resolvedUrl("../../assets/icons/bluetooth_connected.svg")
                        : Qt.resolvedUrl("../../assets/icons/bluetooth.svg")
                    width: 26
                    height: 26
                    sourceSize.width: 52
                    sourceSize.height: 52
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                Layout.minimumWidth: 0

                Text {
                    text: "Bluetooth"
                    color: Colors.fg
                    font.pixelSize: 15
                    font.family: Colors.fontFamily
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }
                Text {
                    text: {
                        if (!BluetoothService.available)
                            return "Unavailable";
                        if (!BluetoothService.enabled)
                            return "Off";
                        if (BluetoothService.connectedName.length > 0)
                            return BluetoothService.connectedName;
                        return "On";
                    }
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            MouseArea {
                id: rescanArea
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                visible: root.expanded
                onClicked: BluetoothService.startScan()

                Text {
                    anchors.centerIn: parent
                    text: BluetoothService.discovering ? "…" : "⟳"
                    color: Colors.fgMuted
                    font.pixelSize: 18
                    scale: rescanArea.pressed ? 0.85 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
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
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Text {
                    visible: !BluetoothService.enabled
                    text: "Turn bluetooth on to see devices"
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                }

                Text {
                    visible: BluetoothService.enabled && BluetoothService.devices.length === 0
                    text: BluetoothService.discovering ? "Scanning…" : "No devices found"
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                }

                
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(deviceColumn.implicitHeight, root.maxListHeight)
                    contentWidth: width
                    contentHeight: deviceColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: BluetoothService.enabled && BluetoothService.devices.length > 0

                    ColumnLayout {
                        id: deviceColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: BluetoothService.enabled ? BluetoothService.devices : []

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 44
                                radius: 12
                                color: Colors.bgX
                                border.color: Colors.blue
                                border.width: deviceRowArea.pressed ? 2 : 0

                                Behavior on border.width {
                                    NumberAnimation { duration: 90 }
                                }

                                // modelData is a BluetoothDevice - see BluetoothService.qml

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: modelData.name
                                        color: Colors.fg
                                        font.pixelSize: 14
                                        font.family: Colors.fontFamily
                                        font.bold: modelData.connected
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: modelData.pairing
                                        text: "Pairing…"
                                        color: Colors.fgMuted
                                        font.pixelSize: 12
                                        font.family: Colors.fontFamily
                                    }

                                    Text {
                                        visible: modelData.connected
                                        text: "Connected"
                                        color: Colors.green
                                        font.pixelSize: 12
                                        font.family: Colors.fontFamily
                                    }

                                    Text {
                                        visible: !modelData.connected && !modelData.pairing && modelData.paired
                                        text: "Paired"
                                        color: Colors.fgMuted
                                        font.pixelSize: 12
                                        font.family: Colors.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: deviceRowArea
                                    anchors.fill: parent
                                    enabled: !modelData.pairing
                                    onClicked: {
                                        if (modelData.connected) {
                                            BluetoothService.disconnectDevice(modelData);
                                        } else {
                                            BluetoothService.connectDevice(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // click
    MouseArea {
        id: cardArea
        anchors.fill: parent
        z: -1
        onClicked: singleClickTimer.restart()
        onDoubleClicked: {
            singleClickTimer.stop();
            root.expanded = !root.expanded;
        }
    }

    Timer {
        id: singleClickTimer
        interval: 250
        onTriggered: BluetoothService.toggle()
    }
}