import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var musicData: null

    property bool hasLyrics: false
    property bool loading: false
    property string currentLine: ""

    property string previousLine: ""
    property real lastChangeTime: 0

    function handleMessage(payload) {
        if (!payload || !payload.type) return

        if (payload.type === "status") {
            const status = payload.status
            if (status === "synced" || status === "plain") {
                root.hasLyrics = true
                root.loading = false
            } else if (status === "searching" || status === "retrying") {
                root.loading = true
            } else if (status === "idle" || status === "error" || status === "not_found") {
                root.hasLyrics = false
                root.loading = false
                root.currentLine = ""
            }
        } else if (payload.type === "line") {
            const incoming = payload.text !== undefined ? payload.text : ""
            
            if (incoming === root.currentLine) return

            const now = Date.now()
            
            if (incoming === root.previousLine && (now - root.lastChangeTime) < 400) {
                return
            }
            
            root.previousLine = root.currentLine
            root.lastChangeTime = now
            root.currentLine = incoming
        }
    }

    Process {
        id: lyricsBackend

        command: ["lyricsmpris", "--pipe"]

        running: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()

                if (!line)
                    return

                try {
                    const payload = JSON.parse(line)
                    root.handleMessage(payload)
                } catch (e) {
                    console.warn(
                        "[LyricsService] Invalid lyricsmpris output:",
                        line
                    )
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                const line = data.trim()

                if (line)
                    console.warn("[lyricsmpris]", line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.warn(
                "[LyricsService] lyricsmpris exited:",
                exitCode
            )

            root.hasLyrics = false
            root.loading = false
            root.currentLine = ""
        }
    }
}
