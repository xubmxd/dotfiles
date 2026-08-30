import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Item {
    id: dashboardRoot

    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color backgroundColor: "#000000"
    property color subtleColor: "#888888"

    property var activePlayer: {
        let players = Mpris.players.values
        if (players.length === 0) return null
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === 1) return players[i]
        }
        for (let i = 0; i < players.length; i++) {
            if (players[i].canPlay) return players[i]
        }
        return players[0]
    }

    function getKanji(id) {
        const kanji = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        return id > 0 && id < 10 ? kanji[id] : id.toString()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        visible: modelData.id > 0
                        width: visible ? 28 : 0
                        height: visible ? 28 : 0
                        radius: 14
                        color: modelData.active ? dashboardRoot.activeColor : "transparent"
                        border.color: modelData.active ? "transparent" : dashboardRoot.subtleColor
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            text: dashboardRoot.getKanji(modelData.id)
                            color: modelData.active ? dashboardRoot.backgroundColor : dashboardRoot.textColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: new Date().toLocaleDateString(Qt.locale(), "ddd, MMM d")
                color: dashboardRoot.subtleColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: dashboardRoot.subtleColor
            opacity: 0.25
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒮"
                    color: dashboardRoot.subtleColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dashboardRoot.activePlayer) {
                                dashboardRoot.activePlayer.previous()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.color: dashboardRoot.subtleColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: dashboardRoot.activePlayer && dashboardRoot.activePlayer.playbackState === 1 ? "󰏤" : "󰐊"
                        color: dashboardRoot.activeColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dashboardRoot.activePlayer && dashboardRoot.activePlayer.canPlay) {
                                dashboardRoot.activePlayer.togglePlaying()
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒭"
                    color: dashboardRoot.subtleColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dashboardRoot.activePlayer) {
                                dashboardRoot.activePlayer.next()
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: dashboardRoot.activePlayer && dashboardRoot.activePlayer.trackTitle ? dashboardRoot.activePlayer.trackTitle : "System Idle"
                    color: dashboardRoot.textColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: dashboardRoot.activePlayer && dashboardRoot.activePlayer.trackArtist ? dashboardRoot.activePlayer.trackArtist : "Hyprland Session"
                    color: dashboardRoot.subtleColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }
        }
    }
}
