import QtQuick
import Qt5Compat.GraphicalEffects

// 7. LYRICS PILL UI (Purely Presentational)
Item {
    id: root

    property var playerData
    property var lyricsService

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7" // Fallback color, can be mapped in shell.qml

    Text {
        id: lyricMeasure
        visible: false
        text: root.lyricsService ? root.lyricsService.currentLine : ""
        font.family: "sans-serif"
        font.pixelSize: 15
        font.weight: Font.Medium
    }

    // Increased slightly to accommodate larger font metrics
    readonly property real fixedHorizontalSpace: 138
    readonly property real minWidth: 200
    readonly property real maxWidth: 1000
    readonly property real compactImplicitWidth:
        Math.max(minWidth, Math.min(maxWidth, fixedHorizontalSpace + lyricMeasure.implicitWidth))

    readonly property bool ready:
        playerData && playerData.hasTrack
        && lyricsService && lyricsService.hasLyrics

    Item {
        id: art
        width: 30
        height: 30
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: artImage
            anchors.fill: parent
            source: root.playerData ? root.playerData.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
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
            radius: 9
            color: Qt.rgba(1, 1, 1, 0.06)
            visible: artImage.source.toString() === ""

            Text {
                anchors.centerIn: parent
                text: "󰝚"
                color: root.subtleColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
        }
    }

    // ==========================================
    // AUDIO VISUALIZER 
    // ==========================================
    Item {
        id: visualizerContainer
        
        width: 32
        height: 24
        
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        
        // Hide it cleanly if the music pauses
        opacity: (root.playerData && root.playerData.isPlaying) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Row {
            anchors.centerIn: parent
            spacing: 3
            
            Timer {
                id: visTimer
                interval: 100
                running: root.playerData && root.playerData.isPlaying
                repeat: true
                property real phase: 0
                onTriggered: phase += 0.4
            }

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

    Item {
        id: stack

        anchors.left: art.right
        anchors.leftMargin: 18
        
        anchors.right: visualizerContainer.left
        anchors.rightMargin: 18
        
        anchors.verticalCenter: parent.verticalCenter
        // Increased from 16 to 22 to prevent descenders (g, j, p, q, y) from cutting off
        height: 22
        clip: true

        property bool aFront: true

        Text {
            id: labelA
            width: Math.min(lyricMeasure.implicitWidth, root.maxWidth - root.fixedHorizontalSpace)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: root.textColor
            font.family: "sans-serif"
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            y: 0
            opacity: 1

            property bool suppressAnim: false

            Behavior on y {
                enabled: !labelA.suppressAnim
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: !labelA.suppressAnim
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: labelB
            width: Math.min(lyricMeasure.implicitWidth, root.maxWidth - root.fixedHorizontalSpace)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: root.textColor
            font.family: "sans-serif"
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            y: stack.height
            opacity: 0

            property bool suppressAnim: false

            Behavior on y {
                enabled: !labelB.suppressAnim
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: !labelB.suppressAnim
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        function showLyric(text) {
            if (text === (aFront ? labelA.text : labelB.text)) return

            const incoming = aFront ? labelB : labelA
            const outgoing = aFront ? labelA : labelB

            incoming.suppressAnim = true
            incoming.text = text
            incoming.y = stack.height
            incoming.opacity = 0
            incoming.suppressAnim = false

            outgoing.y = -stack.height
            outgoing.opacity = 0

            incoming.y = 0
            incoming.opacity = 1

            aFront = !aFront
        }
        
        function instantClear() {
            labelA.suppressAnim = true
            labelB.suppressAnim = true
            labelA.text = ""
            labelB.text = ""
            labelA.opacity = 0
            labelB.opacity = 0
            labelA.suppressAnim = false
            labelB.suppressAnim = false
        }
    }

    Connections {
        target: root.lyricsService
        
        function onCurrentLineChanged() {
            const text = root.lyricsService ? root.lyricsService.currentLine : ""
            stack.showLyric(text)
        }
        
        function onHasLyricsChanged() {
            if (!root.lyricsService || !root.lyricsService.hasLyrics) {
                stack.instantClear()
            }
        }
    }
}
