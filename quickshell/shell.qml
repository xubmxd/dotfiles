import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import "components" as CustomComponents

ShellRoot {
    PanelWindow {
        id: islandWindow

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "custom-island"
        WlrLayershell.exclusiveZone: 40

        color: "transparent"

        // ============================================================
        // TIDE-STYLE SURFACE ARCHITECTURE
        //
        // The PanelWindow spans the screen width.
        //
        // ONLY the Region mask receives pointer input, so transparent
        // areas do not block clicks on windows underneath.
        // ============================================================

        anchors {
            top: true
            left: true
            right: true
        }

        margins.top: 5

        mask: Region {
            Region {
                x: Math.floor(islandBackground.x)
                y: Math.floor(islandBackground.y)
                width: Math.ceil(islandBackground.width)
                height: Math.ceil(islandBackground.height)
            }
        }

        // ============================================================
        // SURFACE HEIGHT MANAGEMENT
        //
        // The Wayland surface grows immediately when content expands.
        //
        // During collapse, we retain the previous height briefly so the
        // height animation can finish without clipping the island.
        //
        // This follows the same general idea Tide uses.
        // ============================================================

        readonly property real requestedWindowHeight:
            Math.ceil(islandBackground.y
                      + islandBackground.targetHeight
                      + 12)

        property real retainedWindowHeight: 0

        implicitHeight:
            Math.max(requestedWindowHeight, retainedWindowHeight)

        function reconcileWindowHeight() {
            if (requestedWindowHeight >= retainedWindowHeight) {
                windowShrinkTimer.stop()
                retainedWindowHeight = requestedWindowHeight
                return
            }

            windowShrinkTimer.restart()
        }

        onRequestedWindowHeightChanged:
            reconcileWindowHeight()

        Component.onCompleted:
            retainedWindowHeight = requestedWindowHeight

        Timer {
            id: windowShrinkTimer

            interval: 500
            repeat: false

            onTriggered:
                islandWindow.retainedWindowHeight =
                    islandWindow.requestedWindowHeight
        }

        // ============================================================
        // PYWAL COLORS
        // ============================================================

        FileView {
            id: pywal

            path:
                Quickshell.env("HOME")
                + "/.cache/wal/colors.json"

            blockLoading: true
            watchChanges: true

            onFileChanged:
                reload()
        }

        property var colors: {
            try {
                var parsed = JSON.parse(pywal.text())

                if (parsed.colors)
                    return parsed.colors
            } catch (error) {
                console.warn(
                    "Failed to load pywal colors:",
                    error
                )
            }

            return {
                color0: "#1a1a1a",
                color1: "#ef4444",
                color2: "#22c55e",
                color3: "#eab308",
                color4: "#3b82f6",
                color5: "#a855f7",
                color6: "#06b6d4",
                color7: "#d1d5db",
                color8: "#555555",
                color9: "#f87171",
                color10: "#4ade80",
                color11: "#facc15",
                color12: "#60a5fa",
                color13: "#c084fc",
                color14: "#22d3ee",
                color15: "#ffffff"
            }
        }

        // ============================================================
        // MUSIC
        // ============================================================

        CustomComponents.MusicPlayerData {
            id: musicData
        }

        property string restingState:
            musicData.hasTrack
            ? "music-compact"
            : "idle"

        Connections {
            target: musicData

            function onHasTrackChanged() {
                const current =
                    islandBackground.islandState

                if (current === "idle"
                    || current === "music-compact"
                    || current === "music-expanded") {

                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }
        }

        // ============================================================
        // AUDIO
        // ============================================================

        PwObjectTracker {
            id: audioTracker

            objects: [
                Pipewire.defaultAudioSink
            ]
        }

        property real trackedVolume: {
            var sink = Pipewire.defaultAudioSink

            if (sink
                && sink.audio
                && sink.audio.volume !== undefined) {

                return sink.audio.volume
            }

            return 0
        }

        property bool isMuted: {
            var sink = Pipewire.defaultAudioSink

            if (sink
                && sink.audio
                && sink.audio.muted !== undefined) {

                return sink.audio.muted
            }

            return false
        }

        // ============================================================
        // GLOBAL STATE
        // ============================================================

        property real trackedBrightness: -1

        property string currentOsd: "volume"

        property bool suppressOsd: true

        property var focusedWorkspace:
            Hyprland.focusedWorkspace

        property bool suppressWsOsd: true

        Timer {
            interval: 1000
            running: true

            onTriggered: {
                islandWindow.suppressOsd = false
                islandWindow.suppressWsOsd = false
            }
        }

        // ============================================================
        // WORKSPACE OSD
        // ============================================================

        onFocusedWorkspaceChanged: {
            if (suppressWsOsd)
                return

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState =
                    "workspace-osd"

                wsOsdTimer.restart()
            }
        }

        // ============================================================
        // VOLUME OSD
        // ============================================================

        onTrackedVolumeChanged: {
            if (suppressOsd)
                return

            currentOsd = "volume"

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        onIsMutedChanged: {
            if (suppressOsd)
                return

            currentOsd = "volume"

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        // ============================================================
        // BRIGHTNESS
        // ============================================================

        Process {
            id: brightnessProc

            command: [
                "brightnessctl",
                "-m"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    var raw =
                        String(text).trim()

                    var parts =
                        raw.split(",")

                    if (parts.length < 4)
                        return

                    var brightness =
                        parseInt(
                            parts[3].replace("%", "")
                        ) / 100.0

                    if (isNaN(brightness))
                        return

                    if (islandWindow.trackedBrightness === -1) {

                        islandWindow.trackedBrightness =
                            brightness

                    } else if (
                        Math.abs(
                            brightness
                            - islandWindow.trackedBrightness
                        ) > 0.01
                    ) {

                        islandWindow.trackedBrightness =
                            brightness

                        islandWindow.currentOsd =
                            "brightness"

                        if (!islandWindow.suppressOsd
                            && !islandMouseArea.containsMouse) {

                            islandBackground.islandState =
                                "osd"

                            osdTimer.restart()
                        }
                    }
                }
            }
        }

        Timer {
            interval: 200
            running: true
            repeat: true

            onTriggered: {
                if (!brightnessProc.running)
                    brightnessProc.running = true
            }
        }

        // ============================================================
        // OSD TIMERS
        // ============================================================

        Timer {
            id: osdTimer

            interval: 2000

            onTriggered: {
                if (!islandMouseArea.containsMouse) {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }
        }

        Timer {
            id: wsOsdTimer

            interval: 1500

            onTriggered: {
                if (!islandMouseArea.containsMouse) {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }
        }

        // ============================================================
        // TIDE-STYLE HOVER LOGIC
        //
        // IMPORTANT:
        //
        // Timers don't blindly trust onExited().
        //
        // They check containsMouse AGAIN when firing.
        //
        // This prevents transient pointer changes from immediately
        // collapsing the island.
        // ============================================================

        property bool hoverExpandedActive: false

        Timer {
            id: hoverExpandDelayTimer

            interval: 250
            repeat: false

            onTriggered: {
                if (!islandMouseArea.containsMouse)
                    return

                if (islandBackground.islandState
                    !== "music-compact") {

                    return
                }

                islandWindow.hoverExpandedActive = true

                islandBackground.islandState =
                    "music-expanded"
            }
        }

        Timer {
            id: hoverCollapseDelayTimer

            interval: 250
            repeat: false

            onTriggered: {
                if (islandMouseArea.containsMouse)
                    return

                // Dashboard hover state
                if (islandBackground.islandState === "hover") {

                    islandBackground.islandState =
                        islandWindow.restingState

                    return
                }

                // Hover-expanded music
                if (islandWindow.hoverExpandedActive
                    && islandBackground.islandState
                    === "music-expanded") {

                    islandWindow.hoverExpandedActive =
                        false

                    islandBackground.islandState =
                        islandWindow.restingState

                    return
                }

                // Restart interrupted OSD timers
                if (islandBackground.islandState === "osd") {
                    osdTimer.restart()
                    return
                }

                if (islandBackground.islandState
                    === "workspace-osd") {

                    wsOsdTimer.restart()
                }
            }
        }

        // ============================================================
        // DYNAMIC ISLAND
        // ============================================================

        Rectangle {
            id: islandBackground

            anchors.top: parent.top
            anchors.horizontalCenter:
                parent.horizontalCenter

            property string islandState: "idle"

            // --------------------------------------------------------
            // TARGET WIDTH
            // --------------------------------------------------------

            readonly property real targetWidth: {
                switch (islandState) {

                case "idle":
                    return 120

                case "hover":
                    return 380

                case "osd":
                    return 300

                case "workspace-osd":
                    return 260

                case "music-compact":
                    return 320

                case "music-expanded":
                    return 380

                default:
                    return 120
                }
            }

            // --------------------------------------------------------
            // TARGET HEIGHT
            // --------------------------------------------------------

            readonly property real targetHeight: {
                switch (islandState) {

                case "idle":
                    return 40

                case "hover":
                    return 125

                case "osd":
                    return 60

                case "workspace-osd":
                    return 50

                case "music-compact":
                    return 64

                case "music-expanded":
                    return 440

                default:
                    return 40
                }
            }

            // --------------------------------------------------------
            // TARGET RADIUS
            // --------------------------------------------------------

            readonly property real targetRadius: {
                switch (islandState) {

                case "idle":
                    return 20

                case "hover":
                    return 24

                case "osd":
                    return 30

                case "workspace-osd":
                    return 25

                case "music-compact":
                    return 32

                case "music-expanded":
                    return 32

                default:
                    return 20
                }
            }

            width: targetWidth
            height: targetHeight
            radius: targetRadius

            color: islandWindow.colors.color0

            opacity: 0.85

            border.color:
                Qt.rgba(1, 1, 1, 0.08)

            border.width: 1

            clip: true

            // ========================================================
            // VISUAL MORPHING
            //
            // The rectangle animates.
            //
            // The PanelWindow width DOES NOT animate with it anymore.
            // ========================================================

            Behavior on width {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            // ========================================================
            // TIDE-STYLE POINTER HANDLING
            //
            // MouseArea uses containsMouse instead of relying on
            // immediate state changes from HoverHandler.
            //
            // z: -1 allows MusicPlayer controls above it to remain
            // clickable.
            // ========================================================

            MouseArea {
                id: islandMouseArea

                anchors.fill: parent

                z: -1

                hoverEnabled: true

                acceptedButtons: Qt.NoButton

                onEntered: {
                    hoverCollapseDelayTimer.stop()

                    // Hovering idle opens dashboard immediately.
                    if (islandBackground.islandState === "idle") {

                        islandWindow.hoverExpandedActive =
                            false

                        islandBackground.islandState =
                            "hover"

                        return
                    }

                    // Hovering compact music starts expansion.
                    if (islandBackground.islandState
                        === "music-compact") {

                        hoverExpandDelayTimer.restart()
                    }
                }

                onExited: {
                    hoverExpandDelayTimer.stop()
                    hoverCollapseDelayTimer.restart()
                }
            }

            // ========================================================
            // CONTENT
            // ========================================================

            Item {
                anchors.fill: parent

                // ----------------------------------------------------
                // CLOCK
                // ----------------------------------------------------

                CustomComponents.Clock {
                    anchors.fill: parent

                    textColor:
                        islandWindow.colors.color15

                    opacity:
                        islandBackground.islandState === "idle"
                        ? 1
                        : 0

                    visible:
                        opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                // ----------------------------------------------------
                // OSD
                // ----------------------------------------------------

                CustomComponents.Osd {
                    anchors.fill: parent

                    activeColor:
                        islandWindow.colors.color4

                    subtleColor:
                        islandWindow.colors.color8

                    backgroundColor:
                        islandWindow.colors.color0

                    osdType:
                        islandWindow.currentOsd

                    osdValue:
                        islandWindow.currentOsd
                        === "volume"
                        ? islandWindow.trackedVolume
                        : (
                            islandWindow.trackedBrightness
                            === -1
                            ? 0
                            : islandWindow.trackedBrightness
                        )

                    isMuted:
                        islandWindow.isMuted

                    opacity:
                        islandBackground.islandState === "osd"
                        ? 1
                        : 0

                    visible:
                        opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                // ----------------------------------------------------
                // DASHBOARD
                // ----------------------------------------------------

                CustomComponents.Dashboard {
                    anchors.fill: parent

                    textColor:
                        islandWindow.colors.color15

                    activeColor:
                        islandWindow.colors.color4

                    backgroundColor:
                        islandWindow.colors.color0

                    subtleColor:
                        islandWindow.colors.color8

                    opacity:
                        islandBackground.islandState === "hover"
                        ? 1
                        : 0

                    visible:
                        opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }
                    }
                }

                // ----------------------------------------------------
                // WORKSPACES
                // ----------------------------------------------------

                CustomComponents.Workspaces {
                    anchors.fill: parent

                    textColor:
                        islandWindow.colors.color15

                    activeColor:
                        islandWindow.colors.color4

                    backgroundColor:
                        islandWindow.colors.color0

                    subtleColor:
                        islandWindow.colors.color8

                    opacity:
                        islandBackground.islandState
                        === "workspace-osd"
                        ? 1
                        : 0

                    visible:
                        opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                // ----------------------------------------------------
                // MUSIC PLAYER
                // ----------------------------------------------------

                CustomComponents.MusicPlayer {
                    anchors.fill: parent

                    playerData:
                        musicData

                    isExpanded:
                        islandBackground.islandState
                        === "music-expanded"

                    textColor:
                        islandWindow.colors.color15

                    activeColor:
                        islandWindow.colors.color4

                    subtleColor:
                        islandWindow.colors.color8

                    backgroundColor:
                        Qt.rgba(1, 1, 1, 0.05)

                    opacity:
                        (
                            islandBackground.islandState
                            === "music-compact"
                            || islandBackground.islandState
                            === "music-expanded"
                        )
                        ? 1
                        : 0

                    visible:
                        opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }
                    }

                    onRequestExpand: {
                        hoverExpandDelayTimer.stop()
                        hoverCollapseDelayTimer.stop()

                        islandWindow.hoverExpandedActive =
                            false

                        islandBackground.islandState =
                            "music-expanded"
                    }

                    onRequestCompact: {
                        hoverExpandDelayTimer.stop()

                        islandWindow.hoverExpandedActive =
                            false

                        islandBackground.islandState =
                            "music-compact"
                    }
                }
            }
        }
    }
}
