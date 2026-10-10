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

    // Backend lifecycle: on-demand to keep ~40 MB resident only while it
    // can do work. Starts with the first tracked song, stops 120 s after
    // the last one (idle delay avoids stop/start churn while skipping
    // tracks). Crash-restart only fires while wanted, so an intentional
    // stop never resurrects the process.
    //
    // backendWanted depends only on external playback state plus a manual
    // latch — never on timer state — so no binding cycle is possible.
    readonly property bool backendWanted: (musicData !== null && musicData !== undefined
        && musicData.hasTrack === true) || idleHold

    // Manual latch: set while a track is recent; cleared by the idle
    // timer. Plain var, written only from the handlers below.
    property bool idleHold: false

    Timer {
        id: backendIdleHold
        interval: 120000
        repeat: false
        onTriggered: root.idleHold = false
    }

    onBackendWantedChanged: {
        if (root.backendWanted) {
            if (!lyricsBackend.running)
                lyricsBackend.running = true
        } else if (lyricsBackend.running) {
            lyricsBackend.running = false
        }
    }

    Connections {
        target: musicData
        function onHasTrackChanged() {
            if (musicData && musicData.hasTrack) {
                root.idleHold = false
                backendIdleHold.stop()
            } else {
                root.idleHold = true
                backendIdleHold.restart()
            }
        }
    }

    Component.onCompleted: {
        if (root.backendWanted && !lyricsBackend.running)
            lyricsBackend.running = true
    }

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

        // NOTE: quickshell inherits a minimal PATH from Hyprland/login
        // (no ~/.local/bin), while lyricsmpris lives in ~/.local/bin.
        // A bare "lyricsmpris" lookup fails with exit 127, so the lyrics
        // pill never gets hasLyrics/loading and never appears.
        // Use an absolute path resolved via $HOME.
        //
        // The pkill first reaps orphaned backends from previous
        // quickshell generations: on restart the old backend (idle, so
        // almost never writing) never sees SIGPIPE and lives on as a
        // ~24MB orphan per restart. The anchored pattern only matches
        // real backend processes — never this wrapper (its cmdline
        // starts with "sh") and never terminal invocations (which lack
        // the absolute-path prefix).
        command: [
            "sh", "-c",
            "pkill -f '^" + Quickshell.env("HOME") + "/.local/bin/lyricsmpris --pipe' 2>/dev/null; " +
            "exec \"" + Quickshell.env("HOME") + "/.local/bin/lyricsmpris\" --pipe"
        ]

        // Started on demand (see backendWanted above), never unconditionally:
        // an idle desktop keeps the ~40 MB backend stopped.
        running: false

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
            root.hasLyrics = false
            root.loading = false
            root.currentLine = ""

            if (!root.backendWanted)
                return // intentional idle stop — stay stopped, stay quiet

            console.warn(
                "[LyricsService] lyricsmpris exited:",
                exitCode
            )

            // Auto-restart so a crash (or a first-run PATH failure)
            // doesn't permanently kill lyrics until next reload.
            backendRestart.restart()
        }
    }

    Timer {
        id: backendRestart
        interval: 2000
        repeat: false
        onTriggered: {
            if (!lyricsBackend.running && root.backendWanted)
                lyricsBackend.running = true
        }
    }
}
