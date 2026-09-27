import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io

Item {
    id: root

    property var playerData
    property string workspaceName: "1"

    // Set once a real BAT* reading arrives; stays false on desktops.
    property bool hasBattery: false
    property int batteryPercent: 100
    property string batteryStatus: "Unknown"

    // Owned by the internal clock engine below.
    property string timeText: Qt.formatDateTime(new Date(), "hh:mm ap")
    property string dateText: Qt.formatDate(new Date(), "MMM d")

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"
    property color dangerColor: "#ef4444"

    signal requestMediaExpand()
    signal requestCalendarToggle()

    // Observable for remote diagnosis (read via `island omniDebug`).
    readonly property alias mediaHovered: mediaHoverArea.containsMouse
    property alias mediaScope: mediaHoverScope
    property alias mediaArea: mediaHoverArea

    readonly property bool hasTrack: !!(root.playerData && root.playerData.hasTrack)
    readonly property bool isPlaying: !!(root.playerData && root.playerData.isPlaying)
    readonly property bool batteryLow: root.hasBattery && root.batteryPercent <= 20
        && root.batteryStatus !== "Charging" && root.batteryStatus !== "Full"

    // ============================================================
    // CLOCK ENGINE (minute granularity is enough — no seconds shown)
    // ============================================================
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const t = Qt.formatDateTime(new Date(), "hh:mm ap")
            const d = Qt.formatDate(new Date(), "MMM d")
            if (t !== root.timeText) root.timeText = t
            if (d !== root.dateText) root.dateText = d
        }
    }

    // ============================================================
    // BATTERY ENGINE
    // ============================================================
    Process {
        id: batteryProc

        command: [
            "sh", "-c",
            "capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"${capacity},${status}\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(text).trim().split(",")
                if (raw.length === 2 && raw[0] !== "" && raw[1] !== "") {
                    root.batteryPercent = parseInt(raw[0])
                    root.batteryStatus = raw[1]
                    root.hasBattery = true
                }
            }
        }

        onExited: (exitCode) => {
            // Transient failure (e.g. sysfs hiccup): retry on next poll.
            if (exitCode !== 0)
                batteryPoll.restart()
        }
    }

    Timer {
        id: batteryPoll
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!batteryProc.running)
                batteryProc.running = true
        }
    }

    Component.onCompleted: {
        batteryProc.running = true
    }

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

    readonly property real compactImplicitWidth: mainLayout.implicitWidth + 32

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    RowLayout {
        id: mainLayout
        // Pinned to the top 40px so the header stays put when the island
        // morphs into the taller omni-expanded state (identical in compact).
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40
        spacing: 12

        // 1. WORKSPACE
        Text {
            text: "Workspace " + root.workspaceName
            color: root.textColor
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignVCenter
        }

        Divider {
            visible: mediaGroup.visible
        }

        // 2-4. MEDIA GROUP — collapses entirely when nothing plays.
        // Wrapped so a NoButton MouseArea (same battle-tested pattern as
        // the island surface) can own media hover without disturbing the
        // RowLayout or stealing clicks from controls.
        Item {
            id: mediaHoverScope
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: mediaGroup.implicitWidth
            Layout.preferredHeight: 40
            visible: root.hasTrack

            RowLayout {
                id: mediaGroup
                anchors.centerIn: parent
                spacing: 8
                visible: root.hasTrack

            Item {
                id: art
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.playerData ? root.playerData.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: false
                    asynchronous: true
                    cache: false
                    // Displayed at 26px: never decode full-res album art
                    // (often 1000px+, ~4-8MB per track) into RAM.
                    sourceSize.width: 56
                    sourceSize.height: 56
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
                    visible: artImage.source.toString() !== ""
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    visible: artImage.source.toString() === ""
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: root.subtleColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }
            }

            Text {
                Layout.maximumWidth: 150
                text: root.hasTrack ? root.playerData.trackTitle : ""
                color: root.subtleColor
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.alignment: Qt.AlignVCenter
            }

            // Reserve space while paused so the island width doesn't jump.
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                opacity: root.isPlaying ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Timer {
                    id: visTimer
                    interval: 100
                    running: root.isPlaying
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
                            height: root.isPlaying
                                    ? 6 + Math.abs(Math.sin(visTimer.phase + index * 0.8)) * 12
                                    : 6
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on height { NumberAnimation { duration: 100 } }
                        }
                    }
                }
            }
            }

            MouseArea {
                id: mediaHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.hasTrack)
                        root.requestMediaExpand()
                }
            }
        }

        Divider {
            visible: true
        }

        // 5. TIME & DATE — secondary hierarchy, smaller + dimmed.
        // Click toggles the attached calendar (same pattern as media).
        Item {
            id: clockScope
            Layout.preferredWidth: clockText.implicitWidth
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: clockText
                anchors.centerIn: parent
                text: root.dateText + " • " + root.timeText
                color: root.subtleColor
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestCalendarToggle()
            }
        }

        Divider {
            visible: batteryGroup.visible
        }

        // 6. BATTERY — hidden on desktops without a battery
        RowLayout {
            id: batteryGroup
            spacing: 5
            visible: root.hasBattery

            Text {
                text: root.getBatteryIcon(root.batteryPercent, root.batteryStatus)
                color: root.batteryLow ? root.dangerColor : root.textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            Text {
                text: root.batteryPercent + "%"
                color: root.batteryLow ? root.dangerColor : root.textColor
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}
