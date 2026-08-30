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
        WlrLayershell.exclusiveZone: 45
        
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
        }

        property var colors: {
            try { return JSON.parse(pywal.data).colors } 
            catch (e) { return { color0: "#0f0f0f", color4: "#ffffff", color8: "#555555", color15: "#ffffff" } }
        }

        PwObjectTracker {
            id: audioTracker
            objects: [Pipewire.defaultAudioSink]
        }

        property real trackedVolume: {
            let sink = Pipewire.defaultAudioSink
            if (sink && sink.audio && sink.audio.volume !== undefined) {
                return sink.audio.volume
            }
            return 0
        }

        property bool isMuted: {
            let sink = Pipewire.defaultAudioSink
            if (sink && sink.audio && sink.audio.muted !== undefined) {
                return sink.audio.muted
            }
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
            if (islandWindow.suppressOsd) return
            islandWindow.currentOsd = "volume"
            if (!hoverHandler.hovered) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }
        
        onIsMutedChanged: {
            if (islandWindow.suppressOsd) return
            islandWindow.currentOsd = "volume"
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
                    let raw = String(text).trim()
                    let parts = raw.split(",")
                    if (parts.length >= 4) {
                        let percentStr = parts[3].replace("%", "")
                        let val = parseInt(percentStr) / 100.0
                        if (!isNaN(val)) {
                            if (islandWindow.trackedBrightness === -1) {
                                islandWindow.trackedBrightness = val
                            } else if (Math.abs(val - islandWindow.trackedBrightness) > 0.01) {
                                islandWindow.trackedBrightness = val
                                islandWindow.currentOsd = "brightness"
                                if (!islandWindow.suppressOsd && !hoverHandler.hovered) {
                                    islandBackground.islandState = "osd"
                                    osdTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }

        Timer {
            interval: 200
            running: true
            repeat: true
            onTriggered: brightnessProc.running = true
        }

        Timer {
            id: osdTimer
            interval: 2000
            onTriggered: {
                if (!hoverHandler.hovered) {
                    islandBackground.islandState = "idle"
                }
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
                    osdValue: islandWindow.currentOsd === "volume" ? islandWindow.trackedVolume : (islandWindow.trackedBrightness === -1 ? 0 : islandWindow.trackedBrightness)
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
