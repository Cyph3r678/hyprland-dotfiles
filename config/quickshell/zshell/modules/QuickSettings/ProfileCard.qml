import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../services"

Rectangle {
    id: root

    implicitHeight: 132
    radius: Colors.radiusCard
    color: Colors.bg1

    // ---- system data ----

    property string userName: Quickshell.env("USER") ?? "User"

    Process {
        id: nameProc
        command: ["bash", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const n = this.text.trim();
                if (n.length > 0) {
                    root.userName = n.charAt(0).toUpperCase() + n.slice(1);
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // ---- avatar ----
        ClippingRectangle {
            id: avatarFrame
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            radius: 10
            color: Colors.bgX

            Image {
                sourceSize.width: 512
                sourceSize.height: 512
                id: avatarImg
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.face"
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }

            Item {
                anchors.fill: parent
                visible: avatarImg.status !== Image.Ready

                Rectangle {
                    width: 28
                    height: 28
                    radius: 10
                    color: Colors.fgMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                }

                Rectangle {
                    width: 46
                    height: 30
                    radius: 15
                    color: Colors.fgMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -6
                }
            }
        }

        // ---- name / greeting / date ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            

            Text {
                text: "Hello " + root.userName + "!"
                color: Colors.fg
                font.pixelSize: 21
                font.bold: true
                font.family: Colors.fontFamily
            }

            Text {
                text: "How are you today?"
                color: Colors.fgMuted
                font.pixelSize: 14
                font.family: Colors.fontFamily
            }

            Rectangle {
                Layout.topMargin: 2
                implicitWidth: dateRow.implicitWidth + 20
                implicitHeight: 30
                radius: 10
                color: Colors.bgX

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14

                        Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("../../assets/icons/calendar.svg")
                    width: 14
                    height: 14
                    sourceSize.width: 52
                    sourceSize.height: 52
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                    }
                    }

                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd, MM/dd/yy")
                        color: Colors.fg
                        font.pixelSize: 12
                        font.family: Colors.fontFamily
                    }
                }
            }
        }

        // ---- clock box ----
        Rectangle {
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            radius: Colors.radiusTile
            color: Colors.blue

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "hh")
                    color: Colors.fg
                    font.pixelSize: 25
                    font.bold: true
                    font.family: Colors.fontFamily
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Colors.fg
                    font.pixelSize: 25
                    font.bold: true
                    font.family: Colors.fontFamily
                }
            }
        }
    }
}