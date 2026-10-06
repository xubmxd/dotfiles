pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ================================================================
// CALENDAR NOTES SERVICE
// ----------------------------------------------------------------
// Notepad-style notes keyed by date ("YYYY-MM-DD"), persisted as a
// single JSON object in ~/.config/quickshell/calendar-notes.json:
//
//   { "2026-10-04": "buy milk\n- [ ] call dentist\n- [x] pay rent" }
//
// Todos are inline syntax inside the note text (not a second schema):
//   "- [ ] task" -> open, "- [x]"/"- [X]" -> done, anything else plain.
// A note with no todo lines is just a note.
// ================================================================

// QtObject cannot host child objects (no default property), but this
// service needs FileView/Timer/Process children — so the root is an
// Item. As a pragma Singleton it never enters a visual tree, so it
// behaves exactly like a QtObject singleton.
Item {
    id: root

    property var notes: ({})
    // Bumped on every mutation so QML bindings re-evaluate even when
    // the object identity is reused.
    property int revision: 0
    // Tracks unsaved mutations for flushNow().
    property bool dirty: false

    readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/calendar-notes.json"

    FileView {
        id: file
        path: root.filePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loadFromFile()
    }

    Component.onCompleted: loadFromFile()

    function pad(n) {
        return (n < 10 ? "0" : "") + n
    }

    function dateKey(y, mZeroBased, d) {
        return y + "-" + pad(mZeroBased + 1) + "-" + pad(d)
    }

    function todayKey() {
        const t = new Date()
        return dateKey(t.getFullYear(), t.getMonth(), t.getDate())
    }

    function loadFromFile() {
        try {
            const raw = String(file.text()).trim()
            if (raw === "") {
                notes = ({})
            } else {
                const parsed = JSON.parse(raw)
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
                    notes = parsed
                else
                    notes = ({})
            }
        } catch (e) {
            console.warn("[CalendarNotes] Failed to parse notes file, starting empty:", e)
            notes = ({})
        }
        revision += 1
    }

    function scheduleSave() {
        saveDebounce.restart()
    }

    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: root.writeToFile()
    }

    // Immediate write, e.g. before closing the editor or switching
    // months. No-op unless something changed since the last write.
    function flushNow() {
        if (!dirty)
            return
        saveDebounce.stop()
        writeToFile()
    }

    function writeToFile() {
        dirty = false
        const payload = JSON.stringify(notes, null, 2) + "\n"
        try {
            if (typeof file.setText === "function") {
                file.setText(payload)
                return
            }
            console.warn("[CalendarNotes] FileView.setText missing, using shell fallback")
        } catch (e) {
            console.warn("[CalendarNotes] setText failed, using shell fallback:", e)
        }
        // Fallback: payload travels as argv ($0), never reinterpreted by
        // the shell, so quotes/newlines/unicode survive intact.
        writer.payload = payload
        writer.running = true
    }

    Process {
        id: writer
        property string payload: ""
        command: ["sh", "-c", "printf '%s' \"$0\" > \"$1\"", payload, root.filePath]
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = String(text).trim()
                if (msg !== "")
                    console.warn("[CalendarNotes] fallback write stderr:", msg)
            }
        }
    }

    function noteFor(key) {
        const v = notes[key]
        return (v === undefined || v === null) ? "" : String(v)
    }

    function hasNote(key) {
        // Touch revision so dots/agenda refresh on mutation.
        revision
        const v = notes[key]
        return v !== undefined && v !== null && String(v).trim() !== ""
    }

    function setNote(key, text) {
        const next = Object.assign({}, notes)
        if (text === undefined || text === null || String(text).trim() === "") {
            if (next[key] === undefined)
                return
            delete next[key]
        } else {
            if (next[key] === text)
                return
            next[key] = String(text)
        }
        notes = next
        revision += 1
        dirty = true
        scheduleSave()
    }

    function deleteNote(key) {
        setNote(key, "")
    }

    // --- todo helpers (inline "- [ ]" / "- [x]" syntax) ---

    function parseTodos(text) {
        const out = []
        const lines = String(text || "").split("\n")
        const re = /^\s*-\s*\[(\s|x|X)\]\s?(.*)$/
        for (let i = 0; i < lines.length; i++) {
            const m = re.exec(lines[i])
            if (m)
                out.push({ line: i, checked: (m[1] === "x" || m[1] === "X"), text: m[2] })
        }
        return out
    }

    function todoCounts(text) {
        const todos = parseTodos(text)
        let open = 0
        for (let i = 0; i < todos.length; i++)
            if (!todos[i].checked)
                open += 1
        return { total: todos.length, open: open }
    }

    function openTodoCount(key) {
        revision
        return todoCounts(noteFor(key)).open
    }

    // True when the date has at least one unchecked "- [ ]" todo.
    // Plain notes (no todo lines) and fully-checked lists return
    // false. Reactive: openTodoCount touches revision.
    function hasOpenTodos(key) {
        return openTodoCount(key) > 0
    }

    function toggleTodo(key, lineIndex) {
        const raw = noteFor(key)
        if (raw === "")
            return raw
        const lines = raw.split("\n")
        if (lineIndex < 0 || lineIndex >= lines.length)
            return raw
        const re = /^(\s*-\s*\[)(\s|x|X)(\]\s?.*)$/
        const m = re.exec(lines[lineIndex])
        if (!m)
            return raw
        const checked = (m[2] === "x" || m[2] === "X")
        lines[lineIndex] = m[1] + (checked ? " " : "x") + m[3]
        const next = lines.join("\n")
        setNote(key, next)
        return next
    }

    // Sorted keys with notes strictly after todayKey, capped at limit.
    // Today is NOT upcoming (k > t, not k >= t).
    function upcoming(limit) {
        revision
        const t = todayKey()
        const keys = []
        for (const k in notes) {
            if (hasNote(k) && k > t)
                keys.push(k)
        }
        keys.sort()
        if (limit !== undefined && limit !== null && keys.length > limit)
            keys.length = limit
        return keys
    }

    function snippet(key, maxLen) {
        const raw = noteFor(key).replace(/\n/g, " ").trim().replace(/ +/g, " ")
        const n = (maxLen === undefined || maxLen === null) ? 42 : maxLen
        if (raw.length <= n)
            return raw
        return raw.slice(0, n - 1) + "…"
    }

    // Single-line preview with "- [ ]"/"- [x]" markers stripped, so the
    // agenda reads as plain text ("hey! · Finish Axiom").
    function plainSnippet(key, maxLen) {
        const lines = String(noteFor(key)).split("\n")
        const clean = []
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].replace(/^\s*-\s*\[(?:\s|x|X)\]\s?/, "").trim()
            if (t !== "")
                clean.push(t)
        }
        const raw = clean.join(" · ")
        const n = (maxLen === undefined || maxLen === null) ? 40 : maxLen
        if (raw.length <= n)
            return raw
        return raw.slice(0, n - 1) + "…"
    }
}
