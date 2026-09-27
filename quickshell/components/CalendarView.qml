import QtQuick
import QtQuick.Layouts

// Month calendar. Pure JS Date logic, no backend. Monday-first grid.
Item {
    id: root

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"

    property date today: new Date()
    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()
    property int selectedDay: -1

    // Refresh "today" if the date rolls over while open.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()

            if (now.getDate() !== root.today.getDate()
                || now.getMonth() !== root.today.getMonth()
                || now.getFullYear() !== root.today.getFullYear()) {
                root.today = now
            }
        }
    }

    // Monday-first offset of the 1st of the shown month.
    readonly property int leadBlanks: (new Date(shownYear, shownMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()
    readonly property int daysInPrevMonth: new Date(shownYear, shownMonth, 0).getDate()
    readonly property string monthLabel: Qt.formatDate(new Date(shownYear, shownMonth, 1), "MMMM yyyy")

    function shiftMonth(delta) {
        var m = root.shownMonth + delta
        var y = root.shownYear

        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }

        root.shownMonth = m
        root.shownYear = y
        root.selectedDay = -1
    }

    function isToday(dayNum) {
        return dayNum === root.today.getDate()
            && root.shownMonth === root.today.getMonth()
            && root.shownYear === root.today.getFullYear()
    }

    ColumnLayout {
        // Fixed implicit height, vertically centered: packs month +
        // weekday + grid as one deliberate block with balanced top and
        // bottom slack. Nothing stretches, so no layout can open a gap.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Month row: nav + label + nav.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 8

            Text {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "‹"
                color: navPrev.containsMouse ? root.textColor : root.subtleColor
                font.family: "Inter"
                font.pixelSize: 20
                font.weight: Font.Bold

                MouseArea {
                    id: navPrev
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(-1)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.monthLabel
                color: root.textColor
                font.family: "Inter"
                font.pixelSize: 15
                font.weight: Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "›"
                color: navNext.containsMouse ? root.textColor : root.subtleColor
                font.family: "Inter"
                font.pixelSize: 20
                font.weight: Font.Bold

                MouseArea {
                    id: navNext
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        // Weekday header.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            spacing: 4

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }

        // Day grid, always 6 fixed rows: stable height, never stretched,
        // so weekday labels and dates stay aligned on any island size.
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 26 + 5 * 4
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: 42

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26

                    readonly property int dayNum: {
                        const n = index - root.leadBlanks + 1

                        if (n < 1)
                            return root.daysInPrevMonth + n

                        if (n > root.daysInMonth)
                            return n - root.daysInMonth

                        return n
                    }
                    readonly property bool inMonth: (index - root.leadBlanks + 1) >= 1
                        && (index - root.leadBlanks + 1) <= root.daysInMonth
                    readonly property bool today: inMonth && root.isToday(dayNum)
                    readonly property bool selected: inMonth && root.selectedDay === dayNum

                    // Today: accent ring + accent text (readable on any theme).
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: "transparent"
                        border.color: root.accentColor
                        border.width: 1.5
                        visible: today
                    }

                    // Selected day: soft fill.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: selected && !today
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayNum
                        color: !inMonth ? Qt.rgba(root.subtleColor.r, root.subtleColor.g, root.subtleColor.b, 0.35)
                            : today ? root.accentColor : root.textColor
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: today || selected ? Font.Bold : Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: inMonth
                        onClicked: {
                            root.selectedDay = (root.selectedDay === dayNum) ? -1 : dayNum
                        }
                    }
                }
            }
        }
    }
}
