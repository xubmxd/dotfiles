import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    PanelWindow {
        id: islandWindow
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "custom-island"
        
        // THE FIX: Tell Hyprland to only reserve 50 pixels of space.
        // When the island expands, it will seamlessly float over your windows.
        WlrLayershell.exclusiveZone: 50
        
        color: "transparent"

        anchors {
            top: true
            bottom: false
            left: false
            right: false
        }
        margins.top: 10

        implicitWidth: 350
        implicitHeight: 100

        FileView {
            id: pywal
            path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        }

        property var colors: {
            try { return JSON.parse(pywal.data).colors } 
            catch (e) { return { color0: "#0f0f0f", color4: "#ffffff", color15: "#ffffff" } }
        }

        Rectangle {
            id: islandBackground
            
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            
            property bool isHovered: hoverHandler.hovered
            property string islandState: isHovered ? "hover" : "idle"
            
            width: islandState === "idle" ? 120 : 350
            height: islandState === "idle" ? 40 : 100
            radius: islandState === "idle" ? 20 : 30
            
            color: islandWindow.colors.color0
            opacity: 0.85
            border.color: islandWindow.colors.color4
            border.width: 1

            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

            HoverHandler {
                id: hoverHandler
            }
        }
    }
}
