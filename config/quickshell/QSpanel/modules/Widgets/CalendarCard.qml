import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../services"

Rectangle {
    id: root

    radius: Colors.radiusCard
    color: Colors.bg1
    clip: true // safety net: if content ever exceeds this card's
                // actual height again, it gets clipped instead of
                // spilling onto the desktop behind it

    // Width is intentionally left alone here - WidgetsWindow always
    // gives this card an explicit Layout.preferredWidth, so this
    // card's own implicit width is never consulted. Height is a
    // different story: WidgetsWindow uses Layout.fillHeight (no
    // preferredHeight) for this card, which means its *own*
    // implicitHeight is what determines how much space it asks for
    // in the first place. Rectangle doesn't auto-derive that from an
    // anchored child, so without this binding it reports 0 - which is
    // what let the whole widgets window get sized too short.
    implicitHeight: mainColumn.implicitHeight + 40 // + top/bottom margins (20 each)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var today: clock.date
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDate: today.getDate()

    readonly property var weekdayNames: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    // Builds a flat 42-cell array (6 weeks x 7 days) for the current
    // month, padded with the tail of last month / start of next month
    // so every week row is complete.
    readonly property var gridCells: {
        const firstOfMonth = new Date(todayYear, todayMonth, 1);
        const startWeekday = firstOfMonth.getDay(); // 0 = Sunday
        const daysInThisMonth = new Date(todayYear, todayMonth + 1, 0).getDate();
        const daysInPrevMonth = new Date(todayYear, todayMonth, 0).getDate();

        const cells = [];
        for (let i = 0; i < startWeekday; i++) {
            cells.push({ day: daysInPrevMonth - startWeekday + 1 + i, current: false, isToday: false });
        }
        for (let d = 1; d <= daysInThisMonth; d++) {
            cells.push({ day: d, current: true, isToday: d === todayDate });
        }
        let next = 1;
        while (cells.length < 42) {
            cells.push({ day: next++, current: false, isToday: false });
        }
        return cells;
    }

    // Splits the flat 42-cell array into 6 week-rows of 7 - rendered
    // as an explicit ColumnLayout-of-RowLayouts below instead of a
    // GridLayout. GridLayout sizes each column from its children's
    // *preferred* width before distributing fill space, and a bare
    // Item (used for each day cell) reports an implicit width of
    // exactly 0 - that mismatch was almost certainly what was causing
    // the squished/overlapping rendering, so this sidesteps it
    // entirely with an explicit, computed cell width instead.
    readonly property var weeks: {
        const rows = [];
        for (let w = 0; w < 6; w++) {
            rows.push(gridCells.slice(w * 7, w * 7 + 7));
        }
        return rows;
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // ---- date pill with calendar icon ----
        Rectangle {
            Layout.alignment: Qt.AlignLeft
            implicitWidth: dateRow.implicitWidth + 24
            implicitHeight: 30
            radius: 10
            color: Colors.bgX

            RowLayout {
                id: dateRow
                anchors.centerIn: parent
                spacing: 8

                Image {
                    source: Qt.resolvedUrl("../../assets/icons/calendar.svg")
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    sourceSize.width: 32
                    sourceSize.height: 32
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: Qt.formatDateTime(root.today, "MMMM d, yyyy").toUpperCase()
                    color: Colors.fg
                    font.pixelSize: 12
                    font.bold: true
                    font.family: Colors.fontFamily
                }
            }
        }

        Text {
            Layout.leftMargin: 10
            text: "CALENDAR"
            color: Colors.fg
            font.pixelSize: 22
            font.bold: true
            font.family: Colors.fontFamily
        }

        // ---- grid area: explicit cell width computed from this
        // item's own width, shared by both the weekday header row and
        // every day-cell row below, so everything lines up exactly. ----
        Item {
            id: gridArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cellWidth: width / 7

            // gridArea is a plain Item, not a Layout, so it doesn't
            // automatically report gridColumn's real size upward the
            // way a Layout would. Without this, mainColumn (and in
            // turn CalendarCard's own implicitHeight, and in turn the
            // whole widgets window's height) all end up computed as
            // if the grid took zero space - which is what let the
            // window get sized too short for the grid to actually
            // fit, spilling the lower week rows out past the card's
            // edges. Width isn't bound here since it's driven the
            // other way (top-down, from Layout.fillWidth), so there's
            // no equivalent gap to fix on that axis.
            implicitHeight: gridColumn.implicitHeight

            ColumnLayout {
                id: gridColumn
                anchors.fill: parent
                spacing: 6

                // weekday header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.weekdayNames

                        delegate: Text {
                            required property string modelData
                            Layout.preferredWidth: gridArea.cellWidth
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Colors.fgMuted
                            font.pixelSize: 11
                            font.bold: true
                            font.family: Colors.fontFamily
                        }
                    }
                }

                // 6 week rows
                Repeater {
                    model: root.weeks

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: parent.modelData

                            delegate: Item {
                                required property var modelData
                                Layout.preferredWidth: gridArea.cellWidth
                                Layout.preferredHeight: 32

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: modelData.isToday ? Colors.blue : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        color: modelData.isToday ? Colors.fg : (modelData.current ? Colors.fg : Colors.fgMuted)
                                        font.pixelSize: 13
                                        font.bold: modelData.isToday
                                        font.family: Colors.fontFamily
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}