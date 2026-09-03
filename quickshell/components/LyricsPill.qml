import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var playerData
    property var lyricsService

    property color textColor: "#ffffff"
    property color subtleColor: "#888888"

    Text {
        id: lyricMeasure
        visible: false
        text: root.lyricsService ? root.lyricsService.currentLine : ""
        font.family: "sans-serif"
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    readonly property real fixedHorizontalSpace: 73
    readonly property real minWidth: 200
    readonly property real maxWidth: 420
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

    Item {
        id: stack

        anchors.left: art.right
        anchors.leftMargin: 9
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: 16
        clip: true

        property bool aFront: true

        Text {
            id: labelA
            width: Math.min(lyricMeasure.implicitWidth, root.maxWidth - root.fixedHorizontalSpace)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: root.textColor
            font.family: "sans-serif"
            font.pixelSize: 13
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
            font.pixelSize: 13
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
            // Do not animate if the identical string was requested
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
