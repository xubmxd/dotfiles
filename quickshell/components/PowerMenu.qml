import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property color textColor: "white"
    property color activeColor: "#89b4fa"
    property color dangerColor: "#f38ba8"
    property color subtleColor: "#a0a0a0"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)

    // hyprctl needs $HYPRLAND_INSTANCE_SIGNATURE to find the compositor's
    // IPC socket — if quickshell started before that var was set, hyprctl
    // fails silently. Fall back to loginctl (talks to systemd-logind
    // instead, doesn't care about Hyprland's env at all) if it does.
    property string lockCommand: "hyprlock"
    property string suspendCommand: "systemctl suspend"
    property string rebootCommand: "systemctl reboot"
    property string shutdownCommand: "systemctl poweroff"

    signal requestClose()

    // Slightly widened to give the Cover Flow breathing room
    readonly property real menuWidth: 420
    readonly property real menuHeight: 140

    property int armedIndex: -1

    ListModel {
        id: actionModel
        ListElement { key: "lock";     label: "Lock";      glyph: "\u{1F512}"; danger: false }
        ListElement { key: "suspend";  label: "Sleep";     glyph: "\u{1F319}"; danger: false }
        ListElement { key: "reboot";   label: "Restart";   glyph: "\u{27F3}";  danger: true }
        ListElement { key: "shutdown"; label: "Shut Down"; glyph: "\u{23FB}";  danger: true }
    }

    onVisibleChanged: {
        if (visible) {
            row.currentIndex = 0
            armedIndex = -1
            forceActiveFocus()
        }
    }

    function runCommand(cmd) {
        runner.command = ["sh", "-c", cmd]
        runner.running = false
        runner.running = true
    }

    Process {
        id: runner

        // If a command fails silently (like hyprctl without the right
        // env), this is where you'll see why — check your quickshell logs.
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0)
                    console.log("[PowerMenu] command stderr:", text)
            }
        }
    }

    function commandFor(key) {
        switch (key) {
        case "lock": return root.lockCommand
        case "suspend": return root.suspendCommand
        case "reboot": return root.rebootCommand
        case "shutdown": return root.shutdownCommand
        }
        return ""
    }

    function activateIndex(index) {
        if (index < 0 || index >= actionModel.count)
            return

        const item = actionModel.get(index)

        // Non-destructive actions fire immediately.
        if (!item.danger) {
            root.runCommand(root.commandFor(item.key))
            root.requestClose()
            return
        }

        // Destructive actions need a second confirm on the same item.
        if (root.armedIndex === index) {
            root.armedIndex = -1
            root.runCommand(root.commandFor(item.key))
            root.requestClose()
        } else {
            root.armedIndex = index
        }
    }

    // ============================================================
    // KEYBOARD NAVIGATION
    // ============================================================

    focus: true

    Keys.onLeftPressed: {
        armedIndex = -1
        row.decrementCurrentIndex()
    }
    Keys.onRightPressed: {
        armedIndex = -1
        row.incrementCurrentIndex()
    }
    Keys.onReturnPressed: activateIndex(row.currentIndex)
    Keys.onEnterPressed: activateIndex(row.currentIndex)
    Keys.onEscapePressed: {
        if (armedIndex !== -1)
            armedIndex = -1
        else
            root.requestClose()
    }

    // ============================================================
    // UI
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
            text: "Power"
            color: root.textColor
            font.pixelSize: 14
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignHCenter
        }

        // Upgraded from ListView to PathView (Cover Flow)
        PathView {
            id: row
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: actionModel
            clip: false

            pathItemCount: 5
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightMoveDuration: 300
            dragMargin: width / 2

            path: Path {
                startX: -row.width * 0.05
                startY: row.height / 2 - 10
                
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0.3 }

                PathLine { x: row.width * 0.25; y: row.height / 2 - 10 }
                PathPercent { value: 0.25 }
                PathAttribute { name: "itemZ"; value: 1 }
                PathAttribute { name: "itemScale"; value: 0.8 }
                PathAttribute { name: "itemOpacity"; value: 0.6 }

                PathLine { x: row.width * 0.5; y: row.height / 2 - 10 }
                PathPercent { value: 0.5 }
                PathAttribute { name: "itemZ"; value: 2 }
                PathAttribute { name: "itemScale"; value: 1.15 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }

                PathLine { x: row.width * 0.75; y: row.height / 2 - 10 }
                PathPercent { value: 0.75 }
                PathAttribute { name: "itemZ"; value: 1 }
                PathAttribute { name: "itemScale"; value: 0.8 }
                PathAttribute { name: "itemOpacity"; value: 0.6 }

                PathLine { x: row.width * 1.05; y: row.height / 2 - 10 }
                PathPercent { value: 1.0 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0.3 }
            }

            delegate: Item {
                id: delegateRoot
                width: 70
                height: row.height

                readonly property bool isCurrent: PathView.isCurrentItem
                readonly property bool isArmed: root.armedIndex === index

                z: PathView.itemZ !== undefined ? PathView.itemZ : 0
                scale: PathView.itemScale !== undefined ? PathView.itemScale : 1.0
                opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1.0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 52
                        height: 52
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        // Smooth color transitions
                        color: delegateRoot.isArmed
                               ? Qt.rgba(root.dangerColor.r, root.dangerColor.g, root.dangerColor.b, 0.22)
                               : root.backgroundColor
                        border.width: delegateRoot.isCurrent ? 2 : 0
                        border.color: delegateRoot.isArmed ? root.dangerColor : Qt.rgba(255, 255, 255, 0.1)

                        // Tactile hover and click feedback
                        scale: mouseArea.pressed && isCurrent ? 0.90 : (isCurrent && mouseArea.containsMouse ? 1.05 : 1.0)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                        Text {
                            anchors.centerIn: parent
                            text: model.glyph
                            font.pixelSize: 22
                            color: root.textColor
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isCurrent) {
                                    root.activateIndex(index)
                                } else {
                                    row.currentIndex = index
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: delegateRoot.isArmed ? "Confirm?" : model.label
                        color: delegateRoot.isArmed
                               ? root.dangerColor
                               : (delegateRoot.isCurrent ? root.textColor : root.subtleColor)
                        font.pixelSize: 11
                        font.weight: delegateRoot.isCurrent ? Font.DemiBold : Font.Normal
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }
    }
}
