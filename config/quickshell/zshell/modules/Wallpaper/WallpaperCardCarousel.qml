import QtQuick
import QtQuick.Effects
import "../../services"

Item {
    id: root

    required property string imagePath
    required property bool isCurrent
    signal clicked()
    signal doubleClicked()

    readonly property int baseWidth: 300
    readonly property int baseHeight: 380
    implicitWidth: isCurrent ? Math.round(baseWidth * 1.50) : Math.round(baseWidth * 0.85)
    implicitHeight: isCurrent ? Math.round(baseHeight * 1.45) : Math.round(baseHeight * 0.9)

    Behavior on implicitWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // How aggressively the card leans - this is a plain horizontal
    // shear (x' = x + shear*y), which is what makes it a true
    // parallelogram (top/bottom edges stay horizontal, left/right
    // edges slant) rather than a rotation (which would slant every
    // edge). Tune to taste - untested against your exact mockup
    // angle.
    readonly property real shear: 0.12

    Item {
        id: card
        anchors.fill: parent

        // Rendering a transformed (sheared) item without going
        // through a layer produces stair-stepped, jagged diagonal
        // edges - the layer forces it through a properly filtered
        // offscreen texture instead.
        layer.enabled: true
        layer.smooth: true

        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(
                1, root.shear, 0, 0,
                0, 1,          0, 0,
                0, 0,          1, 0,
                0, 0,          0, 1)
        }

        MultiEffect {
            source: img
            anchors.fill: img
            z: -1
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 1
            shadowOpacity: 0.8
        }

        Image {
            id: img
            anchors.fill: parent
            source: root.imagePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 400
            sourceSize.height: 500
            smooth: true
        }

        Rectangle {
            anchors.fill: img
            color: "transparent"
            border.width: root.isCurrent ? 3 : 0
            border.color: "#ffffff"
        }
    }

    Rectangle {
        visible: root.isCurrent
        anchors.leftMargin: 215
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -14
        
        radius: 8
        color: "#ffffff"
        height: 28
        width: nameText.implicitWidth + 20

        Text {
            id: nameText
            font.family: Colors.fontFamily
            anchors.centerIn: parent
            text: root.imagePath.split("/").pop()
            color: Colors.bg0
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}