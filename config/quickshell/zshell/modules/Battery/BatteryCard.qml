import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import "../../services"


Item {
    id: root

    
    property url chargingIconSource: "../../assets/icons/charging.svg"
    property url dischargingIconSource: "../../assets/icons/discharge.svg"

    readonly property var device: UPower.displayDevice
    readonly property real rawPercentage: root.device ? root.device.percentage : 0
   
    readonly property int percent: Math.round(root.rawPercentage <= 1 ? root.rawPercentage * 100 : root.rawPercentage)

    readonly property bool isFull: root.device && root.device.state === UPowerDeviceState.FullyCharged
    readonly property bool isCharging: root.device && !UPower.onBattery && !root.isFull

    readonly property color chargingColor: Colors.green
    readonly property color dischargingColor: Colors.red
    readonly property color activeColor: (root.isCharging || root.isFull) ? root.chargingColor : root.dischargingColor

    readonly property string statusLabel: root.isFull ? "Charged" : (root.isCharging ? "Charging" : "Discharging")

    
    property real temperatureCelsius: 35
    readonly property real temperatureFahrenheit: root.temperatureCelsius * 9 / 5 + 32

   
    readonly property string batteryName: {
        if (!root.device || !root.device.nativePath) return "";
        const parts = root.device.nativePath.split("/");
        return parts[parts.length - 1];
    }
    readonly property string temperaturePath: root.batteryName
        ? ("/sys/class/power_supply/" + root.batteryName + "/temp")
        : ""

    FileView {
        id: tempFile
        path: root.temperaturePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const raw = parseFloat(text());
            if (!isNaN(raw))
                root.temperatureCelsius = raw / 10;
        }
    }

    readonly property int etaSeconds: root.isCharging
        ? (root.device ? root.device.timeToFull : 0)
        : (root.device ? root.device.timeToEmpty : 0)
    readonly property string etaText: {
        if (root.isFull) return "Uhhh...Fully charged ><";
        if (root.etaSeconds <= 0) return "";
        const totalMinutes = Math.round(root.etaSeconds / 60);
        const h = Math.floor(totalMinutes / 60);
        const m = totalMinutes % 60;
        const duration = h > 0 ? (h + "h " + m + "m") : (m + "m");
        return root.isCharging ? ("Full charged in " + duration) : ("Discharged in " + duration);
    }

    implicitWidth: 460
    implicitHeight: mainColumn.implicitHeight

    ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: Colors.gapLg

        RowLayout {
            Layout.fillWidth: true
            spacing: Colors.gapLg

            // Capsule gauge
            Rectangle {
                id: capsule
                Layout.topMargin: 20
                Layout.bottomMargin: 20
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.preferredWidth: 200
                Layout.preferredHeight: 100
                radius: height / 2
                color: Colors.bg2 // empty track
                clip: true

                Rectangle {
                    width: parent.width * (root.percent / 100)
                    height: parent.height
                    radius: parent.radius
                    color: root.activeColor

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: root.percent + "%"
                color: Colors.fg
                font.pixelSize: 64
                font.bold: true
                font.family: Colors.fontFamily
            }
        }

        // Status pill
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 10
            color: Colors.bg2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Image {
                    source: (root.isCharging || root.isFull) ? root.chargingIconSource : root.dischargingIconSource
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    text: root.statusLabel
                    color: root.activeColor
                    font.pixelSize: 14
                    font.family: Colors.fontFamily
                }

                Rectangle {
                    Layout.leftMargin: 5
                    width: 6
                    radius: 20
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    color: Colors.bg0
                }

                Text {
                    Layout.leftMargin: 5
                    text: root.temperatureCelsius.toFixed(0) + "\u00B0C - " + root.temperatureFahrenheit.toFixed(0) + "\u00B0F"
                    color: Colors.fg
                    font.pixelSize: 14
                    font.family: Colors.fontFamily
                }

                Rectangle {
                    Layout.leftMargin: 5
                    width: 6
                    radius: 20
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    color: Colors.bg0
                }

                Text {
                    Layout.leftMargin: 0
                    text: root.etaText
                    color: Colors.fg
                    font.pixelSize: 14
                    visible: root.etaText !== ""
                    font.family: Colors.fontFamily
                }

                Item { Layout.fillWidth: true } 
            }
        }
    }
}