import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io // Required for Process and StdioCollector

Item {
    id: root

    property var playerData
    property string workspaceName: "1"
    
    // Dynamic Battery Properties
    property int batteryPercent: 100
    property string batteryStatus: "Unknown"

    // Internal live properties updated by the timer
    property string timeText: Qt.formatDateTime(new Date(), "hh:mm ap")
    property string dateText: Qt.formatDate(new Date(), "MMM d")

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"

    // ============================================================
    // CLOCK ENGINE
    // ============================================================
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.timeText = Qt.formatDateTime(new Date(), "hh:mm ap")
            root.dateText = Qt.formatDate(new Date(), "MMM d")
        }
    }

    // ============================================================
    // BATTERY ENGINE
    // ============================================================
    Process {
        id: batteryProc
        
        // Directly fetch the raw capacity and charging status from the Linux kernel
        command: [
            "sh", "-c",
            "capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"${capacity},${status}\""
        ]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text).trim().split(",")
                if (raw.length === 2 && raw[0] !== "") {
                    root.batteryPercent = parseInt(raw[0])
                    root.batteryStatus = raw[1]
                }
            }
        }
    }

    Timer {
        interval: 30000 // Poll battery every 30 seconds
        running: true
        repeat: true
        onTriggered: {
            batteryProc.running = false
            batteryProc.running = true
        }
    }

    // Fetch immediately when the pill first loads
    Component.onCompleted: {
        batteryProc.running = true
    }

    // Determine the precise Nerd Font icon based on charge level and status
    function getBatteryIcon(percent, status) {
        if (status === "Charging" || status === "Full") return "󰂄"
        if (percent >= 95) return "󰁹"
        if (percent >= 90) return "󰂂"
        if (percent >= 80) return "󰂁"
        if (percent >= 70) return "󰂀"
        if (percent >= 60) return "󰁿"
        if (percent >= 50) return "󰁾"
        if (percent >= 40) return "󰁽"
        if (percent >= 30) return "󰁼"
        if (percent >= 20) return "󰁻"
        if (percent >= 10) return "󰁺"
        return "󰂎"
    }

    // Strictly dynamic width depending purely on content + padding
    readonly property real compactImplicitWidth: mainLayout.implicitWidth + 32

    RowLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: 16

        // 1. WORKSPACE
        Text {
            text: "Workspace " + root.workspaceName
            color: root.textColor
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        // 2. ALBUM ART
        Item {
            id: art
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            visible: root.playerData && root.playerData.hasTrack

            Image {
                id: artImage
                anchors.fill: parent
                source: root.playerData ? root.playerData.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                visible: false
            }

            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: 4
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: artImage
                maskSource: artMask
            }
        }

        // 3. MEDIA TITLE
        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 150
            text: (root.playerData && root.playerData.hasTrack) ? root.playerData.trackTitle : "No Media"
            color: root.textColor
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // 4. VISUALIZER
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 24
            visible: root.playerData && root.playerData.isPlaying

            Timer {
                id: visTimer
                interval: 100
                running: root.playerData && root.playerData.isPlaying
                repeat: true
                property real phase: 0
                onTriggered: phase += 0.4
            }

            Row {
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: 5
                    Rectangle {
                        width: 4
                        radius: 2
                        color: root.accentColor
                        height: root.playerData && root.playerData.isPlaying
                                ? 6 + Math.abs(Math.sin(visTimer.phase + index * 0.8)) * 12
                                : 6
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on height { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }

        // 5. TIME & DATE
        Text {
            text: root.dateText + " • " + root.timeText
            color: root.subtleColor
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        // 6. BATTERY
        Text {
            text: root.getBatteryIcon(root.batteryPercent, root.batteryStatus) + " " + root.batteryPercent + "%"
            // Warn in red if battery is 20% or lower and not charging
            color: root.batteryPercent <= 20 && root.batteryStatus !== "Charging" ? "#ef4444" : root.textColor
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Bold
            
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
}
