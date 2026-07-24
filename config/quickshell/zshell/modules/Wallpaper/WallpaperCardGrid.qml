import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Io
import QtQuick.Layouts
import "../../services"

// Individual grid card: locked to 16:9 (real wallpaper proportions),
// minimal chrome by default - the white border and name pill only
// appear on the actually-selected card, not on hover.
Item {
    id: root

    required property string imagePath
    required property bool isCurrent
    signal clicked()
    signal doubleClicked()

    // Scales up on hover OR selection; border/name pill are
    // isCurrent-only, matching the spec exactly (hover just scales).
    scale: (root.isCurrent || hoverArea.containsMouse) ? 1.25 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    MultiEffect {
        source: card
        anchors.fill: card
        z: -1
        shadowEnabled: root.isCurrent
        shadowColor: "#000000"
        shadowBlur: 1
        shadowOpacity: 0.7
    }
    MultiEffect {
        source: card
        anchors.fill: card
        z: -1
        shadowColor: "#000000"
        shadowBlur: 1
        shadowOpacity: 0.7
    }

    ClippingRectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 20
        radius: 12
        color: "#161616"
        border.width: root.isCurrent ? 3 : 0
        border.color: Colors.fg
        antialiasing: true
        clip: true

        Image {
            id: img
            anchors.fill: parent
            anchors.margins: root.isCurrent ? 0 : 0 // keeps the image inside the border, not under it
            source: root.imagePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 800
            sourceSize.height: 550
            smooth: true
        }
    }

    Rectangle {
        visible: root.isCurrent
        // Anchored to `root`, not `card` - centering against a
        // sibling of the same size is equivalent, but this avoids any
        // ambiguity from anchoring across the scale boundary.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        radius: 8
        color: Colors.fg
        height: 24
        width: nameText.implicitWidth + 16

        Text {
            id: nameText
            font.family: Colors.fontFamily
            anchors.centerIn: parent
            text: root.imagePath.split("/").pop()
            color: Colors.bg0
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}