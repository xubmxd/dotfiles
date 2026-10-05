import QtQuick
import QtQuick.Layouts
import "../services"

// Detached note window content (Tide-style CalendarNoteShell): date
// title, subtitle, close, divider, autosaving editor, todo toggles.
// Self-contained: driven by `dateKey` ("" = closed), persists through
// CalendarNotesService. Emits requestClose() for ×/Esc so the owner can
// clear the selection.
Item {
    id: root

    property string dateKey: ""
    property string fullLabel: ""
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"
    property color surfaceColor: "#1a1a1a"

    signal requestClose()

    readonly property bool hasNote: dateKey !== "" && CalendarNotesService.hasNote(dateKey)
    property string draftText: ""
    property var draftTodos: CalendarNotesService.parseTodos(draftText)
    readonly property int draftOpenCount: {
        let n = 0
        for (let i = 0; i < draftTodos.length; i++)
            if (!draftTodos[i].checked)
                n += 1
        return n
    }
    readonly property string draftSubtitle: draftTodos.length > 0
        ? "Note · " + draftOpenCount + "/" + draftTodos.length + " todos" : "Note"

    function reloadDraft() {
        draftText = dateKey !== "" ? CalendarNotesService.noteFor(dateKey) : ""
        if (noteEditor.text !== draftText) {
            noteEditor.text = draftText
            noteScroll.contentY = 0
        }
    }

    onDateKeyChanged: {
        reloadDraft()
        animateCard()
    }

    Connections {
        target: CalendarNotesService
        function onRevisionChanged() {
            if (root.dateKey !== "" && !noteEditor.activeFocus) {
                root.draftText = CalendarNotesService.noteFor(root.dateKey)
                if (noteEditor.text !== root.draftText)
                    noteEditor.text = root.draftText
            }
        }
    }

    // Tide-style close: flush pending autosave, then ask the owner to
    // clear the selection.
    function closeNote() {
        CalendarNotesService.flushNow()
        root.requestClose()
    }

    // Clearing the text deletes the note via autosave; the card stays
    // open on the placeholder so the user can keep typing.
    function clearNote() {
        if (dateKey === "")
            return
        noteEditor.text = ""
        root.draftText = ""
        CalendarNotesService.deleteNote(dateKey)
        noteEditor.forceActiveFocus()
    }

    function toggleDraftTodo(lineIndex) {
        if (dateKey === "")
            return
        draftText = CalendarNotesService.toggleTodo(dateKey, lineIndex)
        if (noteEditor.text !== draftText)
            noteEditor.text = draftText
    }

    // Tide-style reveal: spring from the calendar edge (380ms OutBack
    // on open, 180ms InCubic on close, unmount after).
    property real cardReveal: 0
    property bool cardMounted: false

    NumberAnimation {
        id: cardRevealAnimation
        target: root
        property: "cardReveal"
    }

    Timer {
        id: cardHideTimer
        interval: 190
        repeat: false
        onTriggered: {
            if (root.dateKey === "")
                root.cardMounted = false
        }
    }

    function animateCard() {
        cardRevealAnimation.stop()
        if (root.dateKey !== "") {
            cardHideTimer.stop()
            root.cardMounted = true
            cardRevealAnimation.to = 1
            cardRevealAnimation.duration = 380
            cardRevealAnimation.easing.type = Easing.OutBack
            cardRevealAnimation.easing.overshoot = 0.45
            cardRevealAnimation.start()
            noteEditor.forceActiveFocus()
        } else {
            // Flush the <400ms autosave tail: the owner clears dateKey
            // when the calendar (or whole island) goes away, e.g. on a
            // workspace switch with the note still open.
            CalendarNotesService.flushNow()
            cardRevealAnimation.to = 0
            cardRevealAnimation.duration = 180
            cardRevealAnimation.easing.type = Easing.InCubic
            cardRevealAnimation.start()
            cardHideTimer.restart()
        }
    }

    Component.onCompleted: {
        reloadDraft()
        root.cardMounted = root.dateKey !== ""
        root.cardReveal = root.dateKey !== "" ? 1 : 0
        if (root.dateKey !== "")
            noteEditor.forceActiveFocus()
    }

    // Detached note window surface: elevated + hairline border +
    // large radius, floating over the desktop like Tide's note shell.
    Rectangle {
        anchors.fill: parent
        visible: root.cardMounted
        opacity: root.cardReveal
        radius: 24
        color: Qt.lighter(root.surfaceColor, 1.25)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        ColumnLayout {
            id: noteCardBody
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            transform: [
                Scale {
                    origin.x: 0
                    origin.y: noteCardBody.height / 2
                    xScale: root.cardReveal
                    yScale: root.cardReveal
                },
                Translate { x: (1 - root.cardReveal) * -12 }
            ]

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.fullLabel
                    color: root.textColor
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: "Delete"
                    color: deleteHover.containsMouse ? root.textColor : root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    visible: root.hasNote

                    MouseArea {
                        id: deleteHover
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearNote()
                    }
                }

                // Tide-style close: × in a 26px circle with hover
                // wash (100ms fade, like Tide).
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    radius: 13
                    color: closeHover.containsMouse
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
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeNote()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.draftSubtitle
                color: root.subtleColor
                font.family: "Inter"
                font.pixelSize: 11
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.09)
            }

            Flickable {
                id: noteScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: Math.max(height, noteEditor.paintedHeight + 4)
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: noteEditor
                    width: noteScroll.width
                    height: Math.max(noteScroll.height, paintedHeight + 4)
                    color: root.textColor
                    selectionColor: "#d7e3f1"
                    selectedTextColor: "#1b1c20"
                    font.family: "Inter"
                    font.pixelSize: 13
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    // No `text:` binding on purpose: user typing would
                    // break it and later draft reloads would stop
                    // showing. Sync is imperative both ways.
                    Component.onCompleted: text = root.draftText
                    onTextChanged: {
                        if (text === root.draftText)
                            return
                        root.draftText = text
                        // Tide-style autosave: every keystroke is
                        // debounced to disk; clearing deletes.
                        if (root.dateKey !== "")
                            CalendarNotesService.setNote(root.dateKey, text)
                    }

                    onCursorRectangleChanged: {
                        const bottom = cursorRectangle.y + cursorRectangle.height
                        if (bottom > noteScroll.contentY + noteScroll.height)
                            noteScroll.contentY = bottom - noteScroll.height
                        else if (cursorRectangle.y < noteScroll.contentY)
                            noteScroll.contentY = cursorRectangle.y
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeNote()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    text: "Write anything…"
                    color: root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 13
                    visible: noteEditor.text.length === 0
                }
            }

            // Inline todo toggles parsed from the draft text (first
            // two; the upcoming sidecar lists them all).
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: root.draftTodos.length > 0

                Repeater {
                    model: root.draftTodos.slice(0, 2)

                    TodoCheckRow {
                        Layout.fillWidth: true
                        checked: modelData.checked
                        todoText: modelData.text
                        textColor: root.textColor
                        subtleColor: root.subtleColor
                        accentColor: root.accentColor
                        onToggled: root.toggleDraftTodo(modelData.line)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "…" + (root.draftTodos.length - 2) + " more in note"
                    color: root.subtleColor
                    font.family: "Inter"
                    font.pixelSize: 10
                    visible: root.draftTodos.length > 2
                }
            }
        }
    }
}
