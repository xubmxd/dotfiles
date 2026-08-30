import QtQuick
import QtQuick.Layouts

Item {
    id: osdRoot

    property color activeColor: "#ffffff"
    property color subtleColor: "#888888"
    property color backgroundColor: "#000000"

    property string osdType: "volume"
    property real osdValue: 0
    property bool isMuted: false

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Text {
            text: {
                if (osdRoot.osdType === "volume") {
                    return osdRoot.isMuted || osdRoot.osdValue === 0 ? "󰝟" : (osdRoot.osdValue < 0.5 ? "󰖀" : "󰕾")
                } else {
                    return osdRoot.osdValue < 0.5 ? "󰃞" : "󰃠"
                }
            }
            color: osdRoot.activeColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
        }

        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: osdRoot.subtleColor

            Rectangle {
                width: parent.width * Math.min(Math.max(osdRoot.osdValue, 0), 1)
                height: parent.height
                radius: 4
                color: osdRoot.activeColor
                
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }
        }
        
        Text {
            text: Math.round(osdRoot.osdValue * 100) + "%"
            color: osdRoot.activeColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
            Layout.minimumWidth: 40
            horizontalAlignment: Text.AlignRight
        }
    }
}
