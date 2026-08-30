import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components" as CustomComponents

ShellRoot {
    PanelWindow {
        id: islandWindow
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "custom-island"
        WlrLayershell.exclusiveZone: 50
        
        color: "transparent"

        anchors {
            top: true
            bottom: false
            left: false
            right: false
        }
        margins.top: 10

        implicitWidth: 380
        implicitHeight: 125

        FileView {
            id: pywal
            path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        }

        property var colors: {
            try { return JSON.parse(pywal.data).colors } 
            catch (e) { return { color0: "#0f0f0f", color4: "#ffffff", color8: "#555555", color15: "#ffffff" } }
        }

        Rectangle {
            id: islandBackground
            
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            
            property bool isHovered: hoverHandler.hovered
            property string islandState: isHovered ? "hover" : "idle"
            
            width: islandState === "idle" ? 120 : 380
            height: islandState === "idle" ? 40 : 125
            radius: islandState === "idle" ? 20 : 24
            
            color: islandWindow.colors.color0
            opacity: 0.92
            border.color: islandWindow.colors.color4
            border.width: 1
            clip: true

            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

            HoverHandler {
                id: hoverHandler
            }

            Item {
                anchors.fill: parent
                
                CustomComponents.Clock {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    
                    opacity: islandBackground.islandState === "idle" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                CustomComponents.Dashboard {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    backgroundColor: islandWindow.colors.color0
                    subtleColor: islandWindow.colors.color8
                    
                    opacity: islandBackground.islandState === "hover" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }
}
