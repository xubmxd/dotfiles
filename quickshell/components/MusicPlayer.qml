import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var playerData
    property bool isExpanded: false

    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color subtleColor: "#888888"
    property color backgroundColor: "#1a1a1a"

    signal requestExpand()
    signal requestCompact()

    // ============================================================
    // DYNAMIC SIZING CALCULATIONS
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

    // 18(left) + 30(art) + 9(gap) + 8(gap) + 32(btn) + 4(right)
    readonly property real compactFixedHorizontalSpace: 101 
    readonly property real compactContentWidth: Math.max(titleMeasure.implicitWidth, artistMeasure.implicitWidth)
    
    // Minimum 180px, maximum 360px (to stay slightly smaller than the 380px expanded view)
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

        // --------------------------------------------------------
        // ALBUM ART
        // --------------------------------------------------------

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

                source: root.playerData
                        ? root.playerData.artUrl
                        : ""

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

        // --------------------------------------------------------
        // TRACK METADATA
        // --------------------------------------------------------

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

                text: root.playerData
                      ? root.playerData.trackTitle
                      : ""

                color: root.textColor

                font.family: "sans-serif"
                font.pixelSize: 11
                font.weight: Font.DemiBold

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width

                text: root.playerData
                      ? root.playerData.trackArtist
                      : ""

                color: root.subtleColor

                font.family: "sans-serif"
                font.pixelSize: 9
                font.weight: Font.Medium

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // --------------------------------------------------------
        // PLAY / PAUSE
        // --------------------------------------------------------

        PlayerControlButton {
            id: compactPlayBtn

            width: 32
            height: 32

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter

            kind: root.playerData && root.playerData.isPlaying
                  ? "pause"
                  : "play"

            activeColor: root.activeColor
            subtleColor: root.subtleColor

            onClicked: {
                if (root.playerData &&
                    root.playerData.activePlayer) {

                    root.playerData.activePlayer.togglePlaying()
                }
            }
        }

        // --------------------------------------------------------
        // CLICK TO EXPAND
        // --------------------------------------------------------

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
        anchors.margins: 24

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
            // LARGE ALBUM ART
            // ----------------------------------------------------

            Item {
                id: expandedArt

                Layout.alignment: Qt.AlignHCenter

                width: 180
                height: 180

                Image {
                    id: expandedArtImage

                    anchors.fill: parent

                    source: root.playerData
                            ? root.playerData.artUrl
                            : ""

                    fillMode: Image.PreserveAspectCrop

                    smooth: true
                    mipmap: true
                    asynchronous: true

                    visible: false
                }

                Rectangle {
                    id: expandedArtMask

                    anchors.fill: parent

                    radius: 18

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

                    radius: 18

                    color: Qt.rgba(1, 1, 1, 0.06)

                    visible: expandedArtImage.source.toString() === ""

                    Text {
                        anchors.centerIn: parent

                        text: "󰝚"

                        color: root.subtleColor

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 48
                    }
                }
            }

            // ----------------------------------------------------
            // TRACK INFO
            // ----------------------------------------------------

            ColumnLayout {
                Layout.fillWidth: true

                spacing: 4

                Text {
                    Layout.fillWidth: true

                    text: root.playerData
                          ? root.playerData.trackTitle
                          : ""

                    color: root.textColor

                    font.family: "sans-serif"
                    font.pixelSize: 18
                    font.weight: Font.Bold

                    horizontalAlignment: Text.AlignHCenter

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true

                    text: root.playerData
                          ? root.playerData.trackArtist
                          : ""

                    color: root.subtleColor

                    font.family: "sans-serif"
                    font.pixelSize: 14
                    font.weight: Font.Medium

                    horizontalAlignment: Text.AlignHCenter

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // ----------------------------------------------------
            // PROGRESS BAR
            // ----------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                spacing: 12

                Text {
                    text: root.playerData
                          ? root.playerData.timePlayed
                          : "0:00"

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

                    color: Qt.rgba(
                        root.subtleColor.r,
                        root.subtleColor.g,
                        root.subtleColor.b,
                        0.2
                    )

                    Rectangle {
                        height: parent.height

                        width: {
                            if (!root.playerData)
                                return 0

                            return parent.width *
                                   Math.max(
                                       0,
                                       Math.min(
                                           1,
                                           root.playerData.trackProgress
                                       )
                                   )
                        }

                        radius: parent.radius

                        color: root.activeColor

                        Behavior on width {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10

                        cursorShape: Qt.PointingHandCursor

                        onClicked: function(mouse) {

                            if (!root.playerData ||
                                !root.playerData.activePlayer ||
                                !root.playerData.activePlayer.canSeek)
                                return

                            const percentage =
                                Math.max(
                                    0,
                                    Math.min(
                                        1,
                                        mouse.x / progressTrack.width
                                    )
                                )

                            const length =
                                Number(
                                    root.playerData
                                        .activePlayer.length
                                ) || 0

                            root.playerData
                                .activePlayer.position =
                                    length * percentage

                            root.playerData.syncProgress()
                        }
                    }
                }

                Text {
                    text: root.playerData
                          ? root.playerData.timeTotal
                          : "0:00"

                    color: root.subtleColor

                    font.family: "sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            // ----------------------------------------------------
            // PLAYER CONTROLS
            // ----------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4

                spacing: 32

                Item {
                    Layout.fillWidth: true
                }

                PlayerControlButton {
                    kind: "prev"

                    activeColor: root.activeColor
                    subtleColor: root.subtleColor

                    enabled:
                        root.playerData &&
                        root.playerData.activePlayer &&
                        root.playerData.activePlayer.canGoPrevious

                    onClicked: {
                        root.playerData
                            .activePlayer
                            .previous()
                    }
                }

                PlayerControlButton {
                    kind:
                        root.playerData &&
                        root.playerData.isPlaying
                        ? "pause"
                        : "play"

                    activeColor: root.activeColor
                    subtleColor: root.subtleColor

                    width: 48
                    height: 48

                    enabled:
                        root.playerData &&
                        root.playerData.activePlayer &&
                        root.playerData.activePlayer.canControl

                    onClicked: {
                        root.playerData
                            .activePlayer
                            .togglePlaying()
                    }
                }

                PlayerControlButton {
                    kind: "next"

                    activeColor: root.activeColor
                    subtleColor: root.subtleColor

                    enabled:
                        root.playerData &&
                        root.playerData.activePlayer &&
                        root.playerData.activePlayer.canGoNext

                    onClicked: {
                        root.playerData
                            .activePlayer
                            .next()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent

            z: -2

            onClicked: root.requestCompact()
        }
    }
}
