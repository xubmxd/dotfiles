import QtQuick

Item {
    id: root

    signal clicked()

    property string kind: "play" // "play", "pause", "next", "prev"
    property color activeColor: "#ffffff"
    property color subtleColor: "#888888"

    width: 36
    height: 36
    
    // Smooth press scaling
    scale: controlArea.pressed ? 0.85 : (controlArea.containsMouse ? 1.05 : 1.0)
    opacity: enabled ? 1.0 : 0.3

    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Subtle hover/press background
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: controlArea.pressed ? Qt.rgba(1, 1, 1, 0.15) : (controlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        // Optically center the play triangle which visually leans left
        anchors.horizontalCenterOffset: root.kind === "play" ? 1 : 0
        text: {
            if (root.kind === "prev") return "󰒮";
            if (root.kind === "next") return "󰒭";
            if (root.kind === "pause") return "󰏤";
            return "󰐊";
        }
        color: root.activeColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.kind === "play" || root.kind === "pause" ? 18 : 16
    }

    MouseArea {
        id: controlArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
