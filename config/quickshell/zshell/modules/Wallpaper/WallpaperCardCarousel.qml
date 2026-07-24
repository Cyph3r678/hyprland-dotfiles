import "../../services"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property string imagePath
    required property bool isCurrent
    readonly property int baseWidth: 300
    readonly property int baseHeight: 380
    // How aggressively the card leans - this is a plain horizontal
    // shear (x' = x + shear*y), which is what makes it a true
    // parallelogram (top/bottom edges stay horizontal, left/right
    // edges slant) rather than a rotation (which would slant every
    // edge).
    readonly property real shear: 0.12

    signal clicked()
    signal doubleClicked()

    implicitWidth: isCurrent ? Math.round(baseWidth * 1.9) : Math.round(baseWidth * 0.85)
    implicitHeight: isCurrent ? Math.round(baseHeight * 1.85) : Math.round(baseHeight * 0.9)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // Carries the shear transform ONLY - `card` and the shadow's
    // MultiEffect both live inside this as untransformed siblings, so
    // they get sheared identically by this shared parent. Putting the
    // transform directly on `card` (which also has layer.enabled) was
    // the bug: MultiEffect sourcing a layered item with its own
    // transform captures the layer's *pre-transform* texture, not its
    // final sheared appearance - which is exactly what produced a
    // second, misaligned rectangle behind the correctly-sheared card.
    Item {
        id: shearedGroup

        anchors.fill: parent

        Item {
            id: card

            anchors.fill: parent
            // layer.smooth alone is just bilinear filtering on a 1x
            // texture - still visibly steps on a hard diagonal edge
            // once sheared. Rendering at 3x and scaling back down for
            // display is real supersampling, which actually removes
            // the stair-stepping.
            layer.enabled: false
            layer.smooth: true
            layer.textureSize: Qt.size(width * 3, height * 3)

            Image {
                id: img

                anchors.fill: parent
                source: root.imagePath
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            Image {
                id: mask

                fillMode: Image.Stretch
                smooth: true
                mipmap: false
                anchors.fill: parent
                source: "../../assets/wallpaper/frame.png"
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: img
                maskSource: mask
                layer.enabled: true
                layer.textureSize: Qt.size(width * 4, height * 4)
            }

            Image {
                anchors.fill: parent
                visible: root.isCurrent
                source: "../../assets/icons/stroke.png"
                fillMode: Image.Stretch
                smooth: true
            }
        }

        MultiEffect {
            source: card
            anchors.fill: card
            z: -1
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 1
            shadowOpacity: 1
            blurMax: 40
        }

    }

    Rectangle {
        visible: root.isCurrent
        anchors.leftMargin: 200
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
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

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

}
