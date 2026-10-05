import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../services"

// Month calendar with per-date notepad notes. Monday-first grid.
//
// The calendar itself is a Tide-style card (month row with vector
// icons + Today pill, day grid, agenda, footer detail line). Notes
// live in a separate note window beside the island (CalendarNoteCard,
// composed in shell.qml) and persist via CalendarNotesService
// (~/.config/quickshell/calendar-notes.json) with autosave. Todo
// lines ("- [ ]"/"- [x]") are toggleable in the agenda and the card.
Item {
    id: root

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"
    // Card surface both calendar and note cards are drawn from (shell
    // passes the pywal background so detached cards match the theme).
    property color surfaceColor: "#1a1a1a"

    property date today: new Date()
    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()
    property int selectedDay: -1

    // Exposed for the island (shell.qml): editing drives the note
    // card, hasUpcoming drives the upcoming sidecar.
    readonly property bool editing: selectedDay !== -1
    readonly property bool hasUpcoming: upcomingKeys.length > 0
    property var upcomingKeys: CalendarNotesService.upcoming(3)

    readonly property string selectedKey: selectedDay !== -1
        ? CalendarNotesService.dateKey(shownYear, shownMonth, selectedDay) : ""

    readonly property var weekdayNamesFull: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNamesShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    readonly property string selectedFullLabel: {
        if (selectedDay === -1)
            return ""
        const d = new Date(shownYear, shownMonth, selectedDay)
        return weekdayNamesFull[d.getDay()] + ", " + selectedDay + " " + monthNamesShort[shownMonth] + " " + shownYear
    }

    signal requestCollapse()

    function refreshAgenda() {
        // Refresh agenda whenever selection/month changes too.
        upcomingKeys = CalendarNotesService.upcoming(3)
    }

    onSelectedKeyChanged: refreshAgenda()
    onShownYearChanged: refreshAgenda()
    onShownMonthChanged: refreshAgenda()

    Connections {
        target: CalendarNotesService
        function onRevisionChanged() {
            // Keep dots + agenda live when the file changes externally.
            root.upcomingKeys = CalendarNotesService.upcoming(3)
        }
    }

    function openKey(key) {
        const parts = String(key).split("-")
        if (parts.length !== 3)
            return
        CalendarNotesService.flushNow()
        root.shownYear = parseInt(parts[0])
        root.shownMonth = parseInt(parts[1]) - 1
        root.selectedDay = parseInt(parts[2])
    }

    // Footer shows the selected date, or today when nothing is
    // selected (Tide-style detail line).
    readonly property bool footerIsToday: selectedDay === -1
    readonly property int footerYear: footerIsToday ? today.getFullYear() : shownYear
    readonly property int footerMonth: footerIsToday ? today.getMonth() : shownMonth
    readonly property int footerDay: footerIsToday ? today.getDate() : selectedDay
    readonly property string footerFullLabel: {
        const d = new Date(footerYear, footerMonth, footerDay)
        return weekdayNamesFull[d.getDay()] + ", " + footerDay + " " + monthNamesShort[footerMonth] + " " + footerYear
    }
    readonly property string footerRelative: {
        const sel = new Date(footerYear, footerMonth, footerDay)
        const tod = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        const diffDays = Math.round((sel.getTime() - tod.getTime()) / 86400000)
        if (diffDays === 0)
            return "Today"
        if (diffDays === 1)
            return "Tomorrow"
        if (diffDays === -1)
            return "Yesterday"
        if (diffDays > 1)
            return "In " + diffDays + " days"
        return Math.abs(diffDays) + " days ago"
    }
    readonly property int footerWeekNumber: getWeekNumber(footerYear, footerMonth, footerDay)

    function getWeekNumber(y, m, d) {
        const target = new Date(Date.UTC(y, m, d))
        target.setUTCDate(target.getUTCDate() + 4 - (target.getUTCDay() || 7))
        const yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1))
        return Math.ceil((((target.getTime() - yearStart.getTime()) / 86400000) + 1) / 7)
    }

    function goToToday() {
        root.shownYear = root.today.getFullYear()
        root.shownMonth = root.today.getMonth()
    }

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
        CalendarNotesService.flushNow()
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
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Tide-style calendar card: own surface + radius, floating over
        // the desktop with a transparent island behind it. The note
        // lives in its own window beside this one (shell.qml).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            // implicitHeight is forwarded from the inner column (a
            // Rectangle won't adopt anchored children's size on its
            // own, which would collapse the layout to zero height).
            implicitHeight: calCardInner.implicitHeight + 24
            radius: 24
            color: root.surfaceColor

            ColumnLayout {
                id: calCardInner
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

        // Month row: glyph + nav + label + Today pill + nav.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 8

            // Tide-style calendar glyph leading the month row.
            Shape {
                Layout.preferredWidth: 15
                Layout.preferredHeight: 15
                Layout.alignment: Qt.AlignVCenter
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.subtleColor
                    strokeWidth: 1.4
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg { path: "M3 4a1.5 1.5 0 0 1 1.5-1.5h6A1.5 1.5 0 0 1 12 4v8a1.5 1.5 0 0 1-1.5 1.5h-6A1.5 1.5 0 0 1 3 12V4zm0 2.5h9M5 1.5v2M10 1.5v2" }
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.fillHeight: true

                // Tide-style vector chevron: brightens + pops on hover,
                // squishes on press (100ms linear, like Tide).
                Shape {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    scale: navPrev.pressed ? 0.85 : (navPrev.containsMouse ? 1.08 : 1.0)
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: navPrev.containsMouse ? root.textColor : root.subtleColor
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg { path: "M9 3L4 7.5L9 12" }
                    }
                }

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
                font.letterSpacing: -0.2
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Tide-style Today pill: jumps the view back to the current
            // month without touching the selected date / open note.
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: todayLabel.implicitWidth + 18
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: todayMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : Qt.rgba(1, 1, 1, 0.06)

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Today"
                    color: todayMouse.containsMouse ? root.textColor : root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.fillHeight: true

                Shape {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    scale: navNext.pressed ? 0.85 : (navNext.containsMouse ? 1.08 : 1.0)
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: navNext.containsMouse ? root.textColor : root.subtleColor
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg { path: "M5 3L10 7.5L5 12" }
                    }
                }

                MouseArea {
                    id: navNext
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                }
            }

            // Collapse × at the end of the month row.
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: 13
                color: collapseHover.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : Qt.rgba(1, 1, 1, 0.06)

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 17
                    font.weight: Font.Light
                }

                MouseArea {
                    id: collapseHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestCollapse()
                }
            }
        }

                // Weekday header. Uses the same GridLayout metrics as the
                // day grid below so each label column lines up exactly
                // with its date column. (A RowLayout of Texts sizes
                // columns from text implicitWidth, which varies per label
                // and drifts vs the grid.)
                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    columns: 7
                    rowSpacing: 0
                    columnSpacing: 4

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 0

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                // Tide dims weekend headers harder than weekdays.
                                color: index >= 5 ? Qt.rgba(1, 1, 1, 0.34) : root.subtleColor
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Day grid, always 6 fixed rows: stable height, never
                // stretched, so weekday labels and dates stay aligned on
                // any island size.
                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6 * 26 + 5 * 4
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: 42

                        // Tide-style cell: hover wash + rounded corners;
                        // the date mark below carries today/selected.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.preferredHeight: 26
                            radius: 7
                            color: cellMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: 0

                            Behavior on color { ColorAnimation { duration: 100 } }

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
                            readonly property string cellKey: inMonth
                                ? CalendarNotesService.dateKey(root.shownYear, root.shownMonth, dayNum) : ""
                            readonly property bool hasNote: cellKey !== "" && CalendarNotesService.hasNote(cellKey)

                            // Tide-style date mark: today is a filled light
                            // circle with dark text; selected is a soft fill
                            // with a hairline border.
                            Rectangle {
                                id: dateMark
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: today
                                    ? "#f1f1f3"
                                    : (selected ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
                                border.width: selected && !today ? 1 : 0
                                border.color: Qt.rgba(1, 1, 1, 0.20)

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    color: today
                                        ? "#111216"
                                        : (!inMonth ? Qt.rgba(root.subtleColor.r, root.subtleColor.g, root.subtleColor.b, 0.35) : root.textColor)
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    font.weight: today || selected ? Font.DemiBold : Font.Normal
                                }
                            }

                            // Tide-style note dot: small white square at the
                            // top-right of the date mark.
                            Rectangle {
                                x: dateMark.x + dateMark.width - 1
                                y: dateMark.y - 2
                                width: 5
                                height: 5
                                radius: 2.5
                                color: "#f5f5f5"
                                visible: hasNote
                            }

                            MouseArea {
                                id: cellMouse
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

                // Tide-style footer detail line: full date on the left,
                // relative day + ISO week on the right.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.09)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.footerFullLabel
                        color: root.subtleColor
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.footerRelative + "  ·  W" + root.footerWeekNumber
                        color: root.subtleColor
                        font.family: "Inter"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refreshAgenda()
    }
}
