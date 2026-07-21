import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services"


PanelWindow {
    id: root

    // State lives here rather than as a plain property on the
    // window, specifically so it survives a Quickshell config reload
    // (hot-reload on save, `qs ipc call ... reload`, etc).
    PersistentProperties {
        id: persist
        reloadableId: "qspanel-powermenu-window"

        property bool menuVisible: false
    }

    // Other code in this file just reads/writes root.menuVisible like
    // before - this alias means nothing else below needed to change.
    property alias menuVisible: persist.menuVisible

    // Reactive binding instead of a Timer guessing the animation
    // duration (the old version unmapped 220ms after hide(), which
    // has to be kept in sync by hand if the Behavior durations below
    // ever change, and doesn't self-correct if you re-open mid-close).
    // cardWrapper's opacity animates smoothly to exactly 0 on close,
    // so once it settles under the threshold the window unmaps itself
    // - no separate timer needed.
    visible: persist.menuVisible || cardWrapper.opacity > 0.001

    property string pendingAction: ""

    readonly property real iconSize: 124

    readonly property string actionVerb: {
        if (pendingAction === "poweroff")
            return "power off";
        if (pendingAction === "logout")
            return "log out";
        if (pendingAction === "reboot")
            return "reboot";
        return "";
    }

    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    exclusiveZone: -1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:powermenu"

    function show() {
        menuVisible = true;
    }

    function hide() {
        menuVisible = false;
        pendingAction = "";
    }

    function toggle() {
        if (menuVisible)
            hide();
        else
            show();
    }

    function requestAction(action) {
        pendingAction = action;
    }

    function confirmYes() {
        if (pendingAction === "poweroff")
            powerOffProc.running = true;
        else if (pendingAction === "logout")
            logoutProc.running = true;
        else if (pendingAction === "reboot")
            rebootProc.running = true;
        pendingAction = "";
        hide();
    }

    function confirmNo() {
        pendingAction = "";
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#99000000"
        opacity: root.menuVisible ? 0.5 : 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Keys.onEscapePressed: root.hide()
        focus: root.menuVisible
    }

    // Two separate stacked cards, not one card with two sections:
    // `backCard` sits behind (with the banner image clipped and inset
    // inside it), `frontCard` (buttons, or the yes/no confirm prompt
    // - same treatment for both) rides up over its bottom edge by
    // `overlapAmount`, each with its own independent shadow so the
    // layering actually reads as depth. Both live inside
    // `cardWrapper`, which is what carries the open/close
    // scale/opacity - they animate together in lockstep rather than
    // the shadows being siblings tracking unscaled bounds (see
    // WidgetsWindow.qml / BatteryWindow.qml / QuickSettingsPanel.qml
    // for where that exact bug first showed up).
    Item {
        id: cardWrapper
        anchors.centerIn: parent
        width: frontCard.width
        height: backCard.height + frontCard.height - overlapAmount
        transformOrigin: Item.Center

        readonly property real overlapAmount: 32
        // Single shared timing for both cards' width/height morph
        // below, so they move in perfect lockstep instead of one
        // trailing the other.
        readonly property int morphDuration: 140

        // Computed ONCE here, from the raw (unanimated) implicit
        // sizes - both backCard and frontCard animate their own
        // width/height off this same raw value independently. This
        // is the actual fix for the sync lag: previously
        // backCard.width was bound straight to frontCard.width, which
        // is itself mid-animation - so backCard was chasing an
        // already-smoothed, constantly-moving target with a second
        // layer of easing stacked on top of it, which is what read as
        // "lagging behind" instead of moving together.
        readonly property real contentWidth: root.pendingAction === "" ? buttonRow.implicitWidth : confirmCol.implicitWidth
        readonly property real contentHeight: root.pendingAction === "" ? buttonRow.implicitHeight : confirmCol.implicitHeight

        scale: root.menuVisible ? 1.0 : 0.50
        opacity: root.menuVisible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 2.8
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        // ---- back layer: a padded background card, with the banner
        // image clipped and inset *inside* it (not the image itself
        // being the shadowed layer) ----
        MultiEffect {
            z: 0
            source: backCard
            anchors.fill: backCard
            autoPaddingEnabled: true
            shadowEnabled: root.menuVisible
            shadowColor: "#000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 1
            blurMax: 40
            shadowOpacity: 1.0
        }

        Rectangle {
            id: backCard
            z: 1
            x: (cardWrapper.width - width) / 2
            y: 0
            // Animates off the same shared cardWrapper.contentWidth
            // that frontCard below also reads from directly - not off
            // frontCard.width itself, which is what caused the lag.
            width: cardWrapper.contentWidth + 48
            height: bannerImage.height + bannerMargin * 2
            radius: 30
            color: Colors.bg0

            readonly property real bannerMargin: 28

            Behavior on width {
                NumberAnimation { duration: cardWrapper.morphDuration; easing.type: Easing.OutCubic }
            }

            ClippingRectangle {
                id: bannerImage
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: parent.bannerMargin
                }
                height: 360
                radius: 20

                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../../assets/powermenu.png")
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }
        }

        // ---- front card (buttons, or confirm prompt) - overlaps
        // the banner's bottom edge and sits above it, shadow and all
        MultiEffect {
            z: 2
            source: frontCard
            anchors.fill: frontCard
            autoPaddingEnabled: true
            shadowEnabled: root.menuVisible
            shadowColor: "#000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 1
            blurMax: 40
            shadowOpacity: 1.0
        }

        Rectangle {
            id: frontCard
            z: 3
            x: (cardWrapper.width - width) / 2
            y: backCard.height - cardWrapper.overlapAmount - 60
            radius: 30
            color: Colors.bg0

            // Both read cardWrapper.contentWidth/contentHeight now
            // (same raw source backCard uses above) rather than
            // computing their own separate copy - keeps this and
            // backCard's width animating off the literal same number
            // every frame.
            width: cardWrapper.contentWidth + 48
            height: cardWrapper.contentHeight + 48

            Behavior on width {
                NumberAnimation { duration: cardWrapper.morphDuration; easing.type: Easing.OutCubic }
            }

            Behavior on height {
                NumberAnimation { duration: cardWrapper.morphDuration; easing.type: Easing.OutCubic }
            }

            // ---- button row (power/logout/reboot) ----
            RowLayout {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 24
                visible: root.pendingAction === ""

                // ---- Power off ----
                Item {
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 240

                    MultiEffect {
                        source: powerBtn
                        anchors.fill: powerBtn
                        z: -1
                        autoPaddingEnabled: true
                        shadowEnabled: powerArea.containsMouse || powerArea.pressed
                        shadowColor: Colors.red
                        shadowBlur: 0.8
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Rectangle {
                        id: powerBtn
                        anchors.fill: parent
                        radius: 20
                        color: "#202020"
                        border.color: Colors.red
                        border.width: (powerArea.containsMouse || powerArea.pressed) ? 2 : 0
                        scale: powerArea.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        Behavior on border.width {
                            NumberAnimation { duration: 120 }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/power.svg")
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize.width: 96
                            sourceSize.height: 96
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.requestAction("poweroff")
                        }
                    }
                }

                // ---- Logout ----
                Item {
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 240

                    MultiEffect {
                        source: logoutBtn
                        anchors.fill: logoutBtn
                        z: -1
                        autoPaddingEnabled: true
                        shadowEnabled: logoutArea.containsMouse || logoutArea.pressed
                        shadowColor: Colors.green
                        shadowBlur: 0.8
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Rectangle {
                        id: logoutBtn
                        anchors.fill: parent
                        radius: 20
                        color: "#202020"
                        border.color: Colors.green
                        border.width: (logoutArea.containsMouse || logoutArea.pressed) ? 2 : 0
                        scale: logoutArea.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        Behavior on border.width {
                            NumberAnimation { duration: 120 }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/logout.svg")
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize.width: 96
                            sourceSize.height: 96
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: logoutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.requestAction("logout")
                        }
                    }
                }

                // ---- Reboot ----
                Item {
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 240

                    MultiEffect {
                        source: rebootBtn
                        anchors.fill: rebootBtn
                        z: -1
                        autoPaddingEnabled: true
                        shadowEnabled: rebootArea.containsMouse || rebootArea.pressed
                        shadowColor: Colors.yellow
                        shadowBlur: 0.8
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Rectangle {
                        id: rebootBtn
                        anchors.fill: parent
                        radius: 20
                        color: "#202020"
                        border.color: Colors.yellow
                        border.width: (rebootArea.containsMouse || rebootArea.pressed) ? 2 : 0
                        scale: rebootArea.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        Behavior on border.width {
                            NumberAnimation { duration: 120 }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("../../assets/icons/reboot.svg")
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize.width: 96
                            sourceSize.height: 96
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: rebootArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.requestAction("reboot")
                        }
                    }
                }
            }

            // ---- confirmation prompt ----
            ColumnLayout {
                id: confirmCol
                anchors.centerIn: parent
                spacing: 16
                visible: root.pendingAction !== ""

                Rectangle {
                    Layout.preferredWidth: 420
                    implicitHeight: questionText.implicitHeight + 32
                    radius: 16
                    color: "#202020"

                    Text {
                        id: questionText
                        anchors.centerIn: parent
                        anchors.margins: 16
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Are you sure you want to " + root.actionVerb + "?"
                        color: Colors.fg
                        font.pixelSize: 18
                        font.family: Colors.fontFamily
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 16
                        color: (yesArea.containsMouse || yesArea.pressed) ? "#272727" : "#202020"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Yes"
                            color: Colors.fg
                            font.pixelSize: 16
                            font.family: Colors.fontFamily
                        }

                        MouseArea {
                            id: yesArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.confirmYes()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 16
                        color: (noArea.containsMouse || noArea.pressed) ? "#272727" : "#202020"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No"
                            color: Colors.fg
                            font.pixelSize: 16
                            font.family: Colors.fontFamily
                        }

                        MouseArea {
                            id: noArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.confirmNo()
                        }
                    }
                }
            }
        }
    }


    Process {
        id: powerOffProc
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: logoutProc
        command: ["hyprctl", "dispatch", "exit"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }
}