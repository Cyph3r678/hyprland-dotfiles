import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../services"

Rectangle {
    id: root

    radius: Colors.radiusCard
    color: "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        Layout.bottomMargin: 0
        anchors.left: parent.left
        anchors.margins: 24
        spacing: -4

        Text {
            text: Qt.formatDateTime(clock.date, "hh")
            color: Colors.blue
            font.pixelSize: 74
            font.bold: true
            font.family: Colors.fontFamily
        }

        RowLayout {
            spacing: 8

            Text {
                Layout.bottomMargin: 10
                text: Qt.formatDateTime(clock.date, "mm")
                color: Colors.fg
                font.pixelSize: 74
                font.bold: true
                font.family: Colors.fontFamily
            }

            Text {
                text: Qt.formatDateTime(clock.date, "AP")
                color: Colors.fgMuted
                font.pixelSize: 34
                font.bold: true
                font.family: Colors.fontFamily
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 20
                Layout.leftMargin: 5
            }
        }
    }
}