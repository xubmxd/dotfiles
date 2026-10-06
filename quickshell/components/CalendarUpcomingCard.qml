import QtQuick
import QtQuick.Layouts
import "../services"

// Tide-style left sidecar: "Today" when today has incomplete todos,
// otherwise "Upcoming" for future notes. Same surface, same rows,
// same toggle/scroll/click behavior either way — only the title and
// the rendered key set change. Emits jumpToDate(key) for header taps.
Item {
    id: root

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"
    property color surfaceColor: "#1a1a1a"

    // Driven by the island: CalendarView.leftCardTitle ("Today" takes
    // priority) and CalendarView.hasTodayTodos.
    property string cardTitle: "Upcoming"
    property bool todayMode: false

    signal jumpToDate(string key)

    // All upcoming notes (cap 14 ≈ two weeks of runway).
    property var upcomingKeys: CalendarNotesService.upcoming(14)

    // Keys actually rendered: today alone in Today mode (all of its
    // todos, open and checked, via the same row rendering), future
    // notes otherwise. Touches revision so toggling/checking todos
    // rebuilds the list in both modes without a manual refresh.
    property var displayKeys: {
        CalendarNotesService.revision
        return todayMode ? [CalendarNotesService.todayKey()] : upcomingKeys
    }

    Connections {
        target: CalendarNotesService
        function onRevisionChanged() {
            root.upcomingKeys = CalendarNotesService.upcoming(14)
        }
    }

    function toggleTodo(key, lineIndex) {
        CalendarNotesService.toggleTodo(key, lineIndex)
        upcomingKeys = CalendarNotesService.upcoming(14)
    }

    function dateLabel(key) {
        const parts = String(key).split("-")
        return Qt.formatDate(
            new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2])),
            "MMM d"
        )
    }

    // Detached surface mirroring the note card: elevated + hairline
    // border + large radius, floating over the desktop.
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.lighter(root.surfaceColor, 1.25)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.cardTitle
                color: root.subtleColor
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.09)
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: agendaColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: agendaColumn
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.displayKeys

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            readonly property string noteKey: modelData
                            readonly property var todos: CalendarNotesService.parseTodos(CalendarNotesService.noteFor(noteKey))

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: 4
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 2
                                    color: CalendarNotesService.openTodoCount(noteKey) > 0 ? root.accentColor : root.subtleColor
                                }

                                Text {
                                    Layout.preferredWidth: 52
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.dateLabel(noteKey)
                                    color: root.textColor
                                    font.family: "Inter"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: CalendarNotesService.plainSnippet(noteKey, 40)
                                    color: root.subtleColor
                                    font.family: "Inter"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                MouseArea {
                                    // Sized, not anchored: direct layout
                                    // child, where anchors are undefined.
                                    width: parent.width
                                    height: parent.height
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.jumpToDate(noteKey)
                                }
                            }

                            Repeater {
                                model: todos

                                TodoCheckRow {
                                    Layout.fillWidth: true
                                    checked: modelData.checked
                                    todoText: modelData.text
                                    textColor: root.textColor
                                    subtleColor: root.subtleColor
                                    accentColor: root.accentColor
                                    onToggled: root.toggleTodo(noteKey, modelData.line)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
