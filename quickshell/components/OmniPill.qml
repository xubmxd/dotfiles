import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var playerData
    property string workspaceName: "1"
    property int batteryPercent: 100

    // Internal live properties updated by the timer
    property string timeText: Qt.formatDateTime(new Date(), "hh:mm ap")
    property string dateText: Qt.formatDate(new Date(), "MMM d")

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"

    // Timer to refresh the clock every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.timeText = Qt.formatDateTime(new Date(), "hh:mm ap")
            root.dateText = Qt.formatDate(new Date(), "MMM d")
        }
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
            font.family: "sans-serif"
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
            font.family: "sans-serif"
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
            font.family: "sans-serif"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        // 6. BATTERY
        Text {
            text: "󰁹 " + root.batteryPercent + "%"
            color: root.textColor
            font.family: "sans-serif"
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }
}
