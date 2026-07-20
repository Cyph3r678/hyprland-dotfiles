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
                    source: Qt.resolvedUrl("../../assets/icons/wifi.svg")
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
                    text: "Wifi"
                    color: Colors.fg
                    font.pixelSize: 15
                    font.family: Colors.fontFamily
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }
                Text {
                    text: {
                        if (!WifiService.enabled)
                            return "Off";
                        if (WifiService.connectedSsid.length > 0)
                            return WifiService.connectedSsid;
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
                onClicked: WifiService.scan()

                Text {
                    anchors.centerIn: parent
                    text: WifiService.scanning ? "…" : "⟳"
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
                    visible: !WifiService.enabled
                    text: "Turn wifi on to see networks"
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                }

                Text {
                    visible: WifiService.enabled && WifiService.networks.length === 0
                    text: WifiService.scanning ? "Scanning…" : "No networks found"
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(networkColumn.implicitHeight, root.maxListHeight)
                    contentWidth: width
                    contentHeight: networkColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: WifiService.enabled && WifiService.networks.length > 0

                    ColumnLayout {
                        id: networkColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: WifiService.enabled ? WifiService.networks : []

                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                property bool showPasswordField: false
                                // modelData: { ssid, signal, secured, inUse }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 44
                                    radius: 12

                                    border.color: Colors.blue
                                    border.width: rowArea.pressed ? 2 : 0
                                    color: Colors.bgX

                                    Behavior on border.width {
                                        NumberAnimation { duration: 90 }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: modelData.ssid
                                            color: Colors.fg
                                            font.pixelSize: 14
                                            font.family: Colors.fontFamily
                                            font.bold: modelData.inUse
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: modelData.inUse
                                            text: "Connected"
                                            color: Colors.green
                                            font.pixelSize: 12
                                            font.family: Colors.fontFamily
                                        }

                                        Text {
                                            visible: WifiService.connecting && WifiService.connectingSsid === modelData.ssid
                                            text: "Connecting…"
                                            color: Colors.fgMuted
                                            font.pixelSize: 12
                                            font.family: Colors.fontFamily
                                        }

                                        Text {
                                            text: modelData.signal + "%"
                                            color: Colors.fgMuted
                                            font.pixelSize: 12
                                            font.family: Colors.fontFamily
                                        }
                                    }

                                    MouseArea {
                                        id: rowArea
                                        anchors.fill: parent
                                        enabled: !modelData.inUse
                                        onClicked: {
                                            if (modelData.secured) {
                                                showPasswordField = !showPasswordField;
                                            } else {
                                                WifiService.connectToNetwork(modelData.ssid, "");
                                            }
                                        }
                                    }
                                }

                                // Inline password entry for secured networks
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: showPasswordField
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 40
                                        radius: 10
                                        color: Colors.bg1
                                        border.color: Colors.blue
                                        border.width: pwField.activeFocus ? 1 : 0

                                        TextInput {
                                            id: pwField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: TextInput.Password
                                            color: Colors.fg
                                            font.pixelSize: 13
                                            font.family: Colors.fontFamily
                                            clip: true
                                            focus: showPasswordField

                                            Keys.onReturnPressed: {
                                                WifiService.connectToNetwork(modelData.ssid, pwField.text);
                                            }
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Password"
                                            color: Colors.fgMuted
                                            font.pixelSize: 13
                                            font.family: Colors.fontFamily
                                            visible: pwField.text.length === 0
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 72
                                        Layout.preferredHeight: 40
                                        radius: 10
                                        color: Colors.blue
                                        scale: connectArea.pressed ? 0.92 : 1.0

                                        Behavior on scale {
                                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Connect"
                                            color: Colors.fg
                                            font.pixelSize: 13
                                            font.family: Colors.fontFamily
                                        }

                                        MouseArea {
                                            id: connectArea
                                            anchors.fill: parent
                                            onClicked: WifiService.connectToNetwork(modelData.ssid, pwField.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: WifiService.lastError.length > 0
                    text: WifiService.lastError
                    color: Colors.red
                    font.pixelSize: 12
                    font.family: Colors.fontFamily
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }


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
        onTriggered: WifiService.toggle()
    }
}