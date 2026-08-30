import QtQuick

Item {
    id: clockRoot
    

    property color textColor: "#ffffff"
    
    Text {
        id: timeText
        anchors.centerIn: parent
        
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        font.bold: true
        color: clockRoot.textColor

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                timeText.text = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap")
            }
            Component.onCompleted: {
                timeText.text = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap")
            }
        }
    }
}
