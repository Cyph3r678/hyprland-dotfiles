import QtQuick
import QtQuick.Layouts
import "../../services"


Rectangle {
    id: root
    
     HoverHandler {
    id: cardHover
    }

    property string label: ""
    property real value: 0            // 0.0-1.0, set this from outside
    property color fillColor: (cardHover.hovered || cardArea.pressed)
       ? Colors.hoverblue
       : Colors.blue

      Behavior on fillColor {
       ColorAnimation {
        duration: 120
         }
     }
    property url iconSource: ""

    signal moved(real newValue)

    implicitHeight: 120
    radius: Colors.radiusCard
    color: Colors.bg1

    property real dragValue: value
    readonly property real displayValue: dragArea.pressed ? dragValue : value

    function ratioFromX(x) {
        const r = x / track.width;
        return Math.max(0, Math.min(1, r));
    }

   
    MouseArea {
        id: clickArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const step = 0.05 * (wheel.angleDelta.y / 120);
            const newValue = Math.max(0, Math.min(1, root.value + step));
            root.moved(newValue);
            wheel.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                color: Colors.fg
                font.pixelSize: 15
                font.family: Colors.fontFamily
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.displayValue * 100) + "%"
                color: Colors.fg
                font.pixelSize: 15
                font.family: Colors.fontFamily
            }
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 14
            color: Colors.bgX
            clip: true
            border.color: root.fillColor
            border.width: dragArea.pressed ? 2 : 0

            Behavior on border.width {
                NumberAnimation { duration: 90 }
            }

            Rectangle {
                width: Math.max(44, track.width * root.displayValue)
                height: parent.height
                radius: 14
                color: root.fillColor

                Behavior on width {
            
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 120 }
                }
            }

            Image {
                source: root.iconSource
                width: 18
                height: 18
                sourceSize.width: 36
                sourceSize.height: 36
                smooth: true
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent

                onPressed: mouse => {
                    root.dragValue = root.ratioFromX(mouse.x);
                    root.moved(root.dragValue);
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        root.dragValue = root.ratioFromX(mouse.x);
                        root.moved(root.dragValue);
                    }
                }

        
                onWheel: wheel => {
                    const step = 0.05 * (wheel.angleDelta.y / 120);
                    const newValue = Math.max(0, Math.min(1, root.value + step));
                    root.moved(newValue);
                    wheel.accepted = true;
                }
            }
        }
    }
}