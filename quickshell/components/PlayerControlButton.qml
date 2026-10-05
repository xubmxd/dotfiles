import QtQuick

Item {
    id: root

    signal clicked()

    property string kind: "play" // "play", "pause", "next", "prev"
    property color activeColor: "#ffffff"
    property color subtleColor: "#888888"

    // Tide-exact metrics: 28px button; glyph ink matched to Tide's
    // rendered 23px glyphs (25px play) measured in Adwaita Mono Bold:
    // prev/next/pause ink 13x12, play ink 13x15.
    width: 28
    height: 28
    
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

    TideIcon {
        anchors.centerIn: parent
        // Optically center the play triangle which visually leans left
        anchors.horizontalCenterOffset: root.kind === "play" ? 1 : 0
        width: root.kind === "play" ? 22 : 21
        height: root.kind === "play" ? 22 : 21
        name: root.kind
        fill: true
        color: root.activeColor
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
