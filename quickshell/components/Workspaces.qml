pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: workspacesRoot

    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color backgroundColor: "#000000"
    property color subtleColor: "#888888"

    property var focusedWorkspace: Hyprland.focusedWorkspace

    signal workspaceActivated()

    function wsLabel(ws) {
        if (!ws)
            return ""
        if (ws.name && isNaN(parseInt(ws.name)))
            return ws.name
        return "Workspace " + ws.id
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 14

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Repeater {
                model: Hyprland.workspaces

                delegate: Rectangle {
                    required property HyprlandWorkspace modelData

                    visible: modelData.id > 0
                    width: visible ? (modelData.active ? 22 : 8) : 0
                    height: visible ? 8 : 0
                    radius: 4
                    color: modelData.active
                        ? workspacesRoot.activeColor
                        : workspacesRoot.subtleColor

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: workspacesRoot.wsLabel(workspacesRoot.focusedWorkspace)
            color: workspacesRoot.textColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
        }
    }
}
