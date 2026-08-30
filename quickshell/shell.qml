import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "components" as CustomComponents

ShellRoot {
    PanelWindow {
        id: islandWindow

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "custom-island"
        WlrLayershell.exclusiveZone: 40

        color: "transparent"

        anchors {
            top: true
            bottom: false
            left: false
            right: false
        }

        margins.top: 5
        implicitWidth: 380
        implicitHeight: 125

        FileView {
            id: pywal
            path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
            blockLoading: true
            watchChanges: true
            onFileChanged: reload()
        }

        property var colors: {
            try {
                var parsed = JSON.parse(pywal.text())
                if (parsed.colors)
                    return parsed.colors
            } catch (error) {
                console.warn("Failed to load pywal colors:", error)
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

        PwObjectTracker {
            id: audioTracker
            objects: [Pipewire.defaultAudioSink]
        }

        property real trackedVolume: {
            var sink = Pipewire.defaultAudioSink
            if (sink && sink.audio && sink.audio.volume !== undefined)
                return sink.audio.volume
            return 0
        }

        property bool isMuted: {
            var sink = Pipewire.defaultAudioSink
            if (sink && sink.audio && sink.audio.muted !== undefined)
                return sink.audio.muted
            return false
        }

        property real trackedBrightness: -1
        property string currentOsd: "volume"
        property bool suppressOsd: true

        Timer {
            interval: 1000
            running: true
            onTriggered: islandWindow.suppressOsd = false
        }

        onTrackedVolumeChanged: {
            if (suppressOsd)
                return
            currentOsd = "volume"
            if (!hoverHandler.hovered) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        onIsMutedChanged: {
            if (suppressOsd)
                return
            currentOsd = "volume"
            if (!hoverHandler.hovered) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        Process {
            id: brightnessProc
            command: ["brightnessctl", "-m"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var raw = String(text).trim()
                    var parts = raw.split(",")

                    if (parts.length < 4)
                        return

                    var brightness = parseInt(parts[3].replace("%", "")) / 100.0

                    if (isNaN(brightness))
                        return

                    if (islandWindow.trackedBrightness === -1) {
                        islandWindow.trackedBrightness = brightness
                    } else if (Math.abs(brightness - islandWindow.trackedBrightness) > 0.01) {
                        islandWindow.trackedBrightness = brightness
                        islandWindow.currentOsd = "brightness"

                        if (!islandWindow.suppressOsd && !hoverHandler.hovered) {
                            islandBackground.islandState = "osd"
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

        Timer {
            id: osdTimer
            interval: 2000
            onTriggered: {
                if (!hoverHandler.hovered)
                    islandBackground.islandState = "idle"
            }
        }

        Rectangle {
            id: islandBackground

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property string islandState: "idle"

            width: islandState === "idle" ? 120 : (islandState === "osd" ? 300 : 380)
            height: islandState === "idle" ? 40 : (islandState === "osd" ? 60 : 125)
            radius: islandState === "idle" ? 20 : (islandState === "osd" ? 30 : 24)

            color: islandWindow.colors.color0
            opacity: 0.75
            border.color: islandWindow.colors.color4
            border.width: 1
            clip: true

            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

            HoverHandler {
                id: hoverHandler
                onHoveredChanged: {
                    if (hovered) {
                        osdTimer.stop()
                        islandBackground.islandState = "hover"
                    } else {
                        islandBackground.islandState = "idle"
                    }
                }
            }

            Item {
                anchors.fill: parent

                CustomComponents.Clock {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    opacity: islandBackground.islandState === "idle" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                CustomComponents.Osd {
                    anchors.fill: parent
                    activeColor: islandWindow.colors.color4
                    subtleColor: islandWindow.colors.color8
                    backgroundColor: islandWindow.colors.color0
                    osdType: islandWindow.currentOsd
                    osdValue: islandWindow.currentOsd === "volume"
                        ? islandWindow.trackedVolume
                        : (islandWindow.trackedBrightness === -1 ? 0 : islandWindow.trackedBrightness)
                    isMuted: islandWindow.isMuted
                    opacity: islandBackground.islandState === "osd" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                CustomComponents.Dashboard {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    backgroundColor: islandWindow.colors.color0
                    subtleColor: islandWindow.colors.color8
                    opacity: islandBackground.islandState === "hover" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }
}
