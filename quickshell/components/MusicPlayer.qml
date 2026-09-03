import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var playerData
    property bool isExpanded: false

    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color accentColor: "#a855f7" // Mapped to color5 in shell.qml
    property color subtleColor: "#888888"
    property color backgroundColor: "#1a1a1a"

    signal requestExpand()
    signal requestCompact()

    // ============================================================
    // DYNAMIC SIZING CALCULATIONS (Used for Compact View)
    // ============================================================

    Text {
        id: titleMeasure
        visible: false
        text: root.playerData ? root.playerData.trackTitle : ""
        font.family: "sans-serif"
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    Text {
        id: artistMeasure
        visible: false
        text: root.playerData ? root.playerData.trackArtist : ""
        font.family: "sans-serif"
        font.pixelSize: 9
        font.weight: Font.Medium
    }

    readonly property real compactFixedHorizontalSpace: 101 
    readonly property real compactContentWidth: Math.max(titleMeasure.implicitWidth, artistMeasure.implicitWidth)
    readonly property real compactImplicitWidth: Math.max(180, Math.min(360, compactFixedHorizontalSpace + compactContentWidth))

    // ============================================================
    // COMPACT VIEW
    // ============================================================

    Item {
        id: compactView

        anchors.fill: parent

        opacity: !root.isExpanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            id: compactArt
            width: 30
            height: 30
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: compactArtImage
                anchors.fill: parent
                source: root.playerData ? root.playerData.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                visible: false
            }

            Rectangle {
                id: compactArtMask
                anchors.fill: parent
                radius: 4
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: compactArtImage
                maskSource: compactArtMask
                visible: compactArtImage.source.toString() !== ""
            }

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.06)
                visible: compactArtImage.source.toString() === ""
                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: root.subtleColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                }
            }
        }

        Column {
            id: compactMetadata
            anchors.left: compactArt.right
            anchors.leftMargin: 9
            anchors.right: compactPlayBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.playerData ? root.playerData.trackTitle : ""
                color: root.textColor
                font.family: "sans-serif"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.playerData ? root.playerData.trackArtist : ""
                color: root.subtleColor
                font.family: "sans-serif"
                font.pixelSize: 9
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        PlayerControlButton {
            id: compactPlayBtn
            width: 32
            height: 32
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            kind: root.playerData && root.playerData.isPlaying ? "pause" : "play"
            activeColor: root.activeColor
            subtleColor: root.subtleColor
            onClicked: {
                if (root.playerData && root.playerData.activePlayer) {
                    root.playerData.activePlayer.togglePlaying()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: root.requestExpand()
        }
    }

    // ============================================================
    // EXPANDED VIEW
    // ============================================================

    Item {
        id: expandedView

        anchors.fill: parent
        anchors.margins: 20

        opacity: root.isExpanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            // ----------------------------------------------------
            // TOP ROW: ART, INFO, VISUALIZER
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Album Art
                Item {
                    id: expandedArt
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64

                    Image {
                        id: expandedArtImage
                        anchors.fill: parent
                        source: root.playerData ? root.playerData.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: false
                    }

                    Rectangle {
                        id: expandedArtMask
                        anchors.fill: parent
                        radius: 12
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: expandedArtImage
                        maskSource: expandedArtMask
                        visible: expandedArtImage.source.toString() !== ""
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.06)
                        visible: expandedArtImage.source.toString() === ""

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            color: root.subtleColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                        }
                    }
                }

                // Track Info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.playerData ? root.playerData.trackTitle : ""
                        color: root.textColor
                        font.family: "sans-serif"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.playerData ? root.playerData.trackArtist : ""
                        color: root.subtleColor
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Animated Visualizer
                Item {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 32
                    visible: root.playerData && root.playerData.hasTrack
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        
                        Timer {
                            id: visTimer
                            interval: 100
                            running: root.isExpanded && root.playerData && root.playerData.isPlaying
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
            }

            // ----------------------------------------------------
            // MIDDLE ROW: PROGRESS BAR
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: progressTrack.seekOverrideActive
                        ? progressTrack.seekOverrideTimeText
                        : (root.playerData ? root.playerData.timePlayed : "0:00")
                    color: root.subtleColor
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Rectangle {
                    id: progressTrack
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(root.subtleColor.r, root.subtleColor.g, root.subtleColor.b, 0.2)

                    property bool dragging: false
                    property real dragPercentage: 0

                    // The backend player applies seeks asynchronously over
                    // DBus. If the position poller reads back the OLD
                    // position before that lands, it snaps the bar back to
                    // the pre-seek spot and keeps ticking from there, then
                    // jerks forward once the real seek finally arrives -
                    // looking exactly like the bar "skipping ahead" on its
                    // own. Hold our optimistic value for a beat so the
                    // stale poll can't clobber it.
                    property bool seekOverrideActive: false
                    property real seekOverridePercentage: 0
                    property string seekOverrideTimeText: "0:00"

                    Timer {
                        id: seekOverrideTimer
                        interval: 1500
                        onTriggered: progressTrack.seekOverrideActive = false
                    }

                    function seekTo(percentage) {
                        if (!root.playerData || !root.playerData.activePlayer || !root.playerData.activePlayer.canSeek) return

                        const player = root.playerData.activePlayer
                        const lengthSec = root.playerData.toSeconds(player.length) || 0
                        const targetSec = Math.max(0, Math.min(lengthSec, lengthSec * percentage))

                        // Quickshell's MprisPlayer reports position/length in
                        // seconds (not raw MPRIS microseconds), and its
                        // position property is directly writable when
                        // positionSupported is true - so set it absolutely
                        // instead of computing a relative offset.
                        if (player.positionSupported) {
                            player.position = targetSec
                        } else if (typeof player.seek === "function") {
                            const currentSec = root.playerData.toSeconds(player.position) || 0
                            player.seek(targetSec - currentSec)
                        }

                        seekOverridePercentage = percentage
                        seekOverrideTimeText = root.playerData.formatTime(targetSec)
                        seekOverrideActive = true
                        seekOverrideTimer.restart()

                        root.playerData.trackProgress = percentage
                        root.playerData.timePlayed = root.playerData.formatTime(targetSec)

                        if (root.playerData.progressPoller) {
                            root.playerData.progressPoller.restart()
                        }
                    }

                    Rectangle {
                        height: parent.height
                        width: {
                            if (!root.playerData) return 0
                            const pct = progressTrack.dragging
                                ? progressTrack.dragPercentage
                                : (progressTrack.seekOverrideActive
                                    ? progressTrack.seekOverridePercentage
                                    : root.playerData.trackProgress)
                            return parent.width * Math.max(0, Math.min(1, pct))
                        }
                        radius: parent.radius
                        color: root.activeColor

                        Behavior on width {
                            enabled: !progressTrack.dragging && !progressTrack.seekOverrideActive
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // scrub handle, visible while dragging - matches the tactile
                    // "grab and drag" feel of Apple's now-playing scrubber
                    Rectangle {
                        visible: progressTrack.dragging
                        width: 12; height: 12; radius: 6
                        color: root.activeColor
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width, parent.width * progressTrack.dragPercentage)) - width / 2
                        scale: progressTrack.dragging ? 1 : 0.6
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.5; mass: 0.6 } }
                    }

                    MouseArea {
                        id: scrubArea
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.playerData && root.playerData.activePlayer && root.playerData.activePlayer.canSeek

                        function percentageFor(mx) {
                            // MouseArea is expanded 10px past progressTrack on every side
                            // (anchors.margins: -10), so its local (0,0) sits 10px before
                            // progressTrack's own origin - subtract that back out or every
                            // click/drag lands 10px off from where the finger actually is.
                            return Math.max(0, Math.min(1, (mx - 10) / progressTrack.width))
                        }

                        onPressed: function(mouse) {
                            progressTrack.dragging = true
                            progressTrack.dragPercentage = percentageFor(mouse.x)
                        }

                        onPositionChanged: function(mouse) {
                            if (!progressTrack.dragging) return
                            progressTrack.dragPercentage = percentageFor(mouse.x)
                        }

                        onReleased: function(mouse) {
                            if (!progressTrack.dragging) return
                            progressTrack.dragging = false
                            progressTrack.seekTo(percentageFor(mouse.x))
                        }

                        onCanceled: {
                            progressTrack.dragging = false
                        }

                        onClicked: function(mouse) {
                            // plain tap (no drag) still seeks straight to that point
                            progressTrack.seekTo(percentageFor(mouse.x))
                        }
                    }
                }

                Text {
                    text: root.playerData ? root.playerData.timeTotal : "0:00"
                    color: root.subtleColor
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            // ----------------------------------------------------
            // BOTTOM ROW: PLAYER CONTROLS
            // ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 32

                Item { Layout.fillWidth: true }

                PlayerControlButton {
                    kind: "prev"
                    activeColor: root.activeColor
                    subtleColor: root.subtleColor
                    enabled: root.playerData && root.playerData.activePlayer && root.playerData.activePlayer.canGoPrevious
                    onClicked: {
                        root.playerData.activePlayer.previous()
                    }
                }

                PlayerControlButton {
                    kind: root.playerData && root.playerData.isPlaying ? "pause" : "play"
                    activeColor: root.activeColor
                    subtleColor: root.subtleColor
                    width: 42
                    height: 42
                    enabled: root.playerData && root.playerData.activePlayer && root.playerData.activePlayer.canControl
                    onClicked: {
                        root.playerData.activePlayer.togglePlaying()
                    }
                }

                PlayerControlButton {
                    kind: "next"
                    activeColor: root.activeColor
                    subtleColor: root.subtleColor
                    enabled: root.playerData && root.playerData.activePlayer && root.playerData.activePlayer.canGoNext
                    onClicked: {
                        root.playerData.activePlayer.next()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -2
            onClicked: root.requestCompact()
        }
    }
}
