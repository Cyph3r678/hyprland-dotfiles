import QtQuick
import QtQuick.Layouts
import "../../services"

Rectangle {
    id: root

    radius: Colors.radiusCard
    color: Colors.bg1
    clip: true // safety net: same reasoning as CalendarCard

    // Same bug/fix as CalendarCard: this card uses Layout.fillHeight
    // (no preferredHeight) in WidgetsWindow, so its own implicitHeight
    // is what the outer layout asks it for. A plain Rectangle doesn't
    // auto-derive that from an anchored child, so without this it
    // reported 0 - which is what squeezed this card down to a sliver
    // of its "REMINDERS" pill in the broken layout.
    implicitHeight: mainColumn.implicitHeight + 40 // + top/bottom margins (20 each)

    property bool adding: false

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // ---- "REMINDERS" pill ----
        Rectangle {
            Layout.alignment: Qt.AlignLeft
            implicitWidth: label.implicitWidth + 48
            implicitHeight: 30
            radius: 10
            color: Colors.bgX
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Image {
                    source: Qt.resolvedUrl("../../assets/icons/rem.svg")
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    sourceSize.width: 32
                    sourceSize.height: 32
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    id: label
                    text: "REMINDERS"
                    color: Colors.fg
                    font.pixelSize: 12
                    font.bold: false
                    font.family: Colors.fontFamily
                }
            }
        }

        // ---- existing reminders (capped height + scroll, same
        // pattern as the wifi/bluetooth device lists) ----
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(reminderColumn.implicitHeight, 96)
            contentWidth: width
            contentHeight: reminderColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: RemindersService.reminders.length > 0

            ColumnLayout {
                id: reminderColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: RemindersService.reminders

                    delegate: Rectangle {
                        id: reminderRow
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: reminderText.implicitHeight + 16
                        radius: 10
                        color: Colors.bgX

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                id: reminderText
                                Layout.fillWidth: true
                                text: reminderRow.modelData
                                color: Colors.fg
                                font.pixelSize: 13
                                font.family: Colors.fontFamily
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                text: "✕"
                                color: Colors.fgMuted
                                font.pixelSize: 13

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: RemindersService.removeAt(reminderRow.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- add button / inline input ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.adding

            Rectangle {
                id: addBtn
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 22
                color: Colors.yellow
                scale: addArea.pressed ? 0.92 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Colors.bg0
                    font.pixelSize: 22
                    font.bold: true
                }

                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    onClicked: root.adding = true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.adding
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 10
                color: Colors.bgX
                border.color: Colors.blue
                border.width: noteInput.activeFocus ? 1 : 0

                TextInput {
                    id: noteInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.fg
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                    clip: true
                    focus: root.adding

                    Keys.onReturnPressed: {
                        RemindersService.add(text);
                        text = "";
                        root.adding = false;
                    }
                    Keys.onEscapePressed: {
                        text = "";
                        root.adding = false;
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type a note, Enter to save…"
                    color: Colors.fgMuted
                    font.pixelSize: 13
                    font.family: Colors.fontFamily
                    visible: noteInput.text.length === 0
                }
            }
        }
    }

    // Autofocus the text field the moment it appears.
    onAddingChanged: if (adding) noteInput.forceActiveFocus()
}