import QtQuick
import Quickshell.Hyprland

Item {
    id: workspaceRoot
    
    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color backgroundColor: "#000000"

    function getKanji(id) {
        const kanji = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        return id > 0 && id < 10 ? kanji[id] : id.toString()
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: Hyprland.workspaces

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: modelData.active ? workspaceRoot.activeColor : "transparent"
                border.color: modelData.active ? "transparent" : alpha(workspaceRoot.textColor, 0.3)
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: workspaceRoot.getKanji(modelData.id)
                    color: modelData.active ? workspaceRoot.backgroundColor : workspaceRoot.textColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.activate()
                }
            }
        }
    }

    function alpha(colorString, opacity) {
        let c = String(colorString)
        return Qt.rgba(
            parseInt(c.slice(1, 3), 16) / 255,
            parseInt(c.slice(3, 5), 16) / 255,
            parseInt(c.slice(5, 7), 16) / 255,
            opacity
        )
    }
}
