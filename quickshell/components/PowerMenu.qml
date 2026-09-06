import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API (matches the rest of your island components)
    // ============================================================

    property color textColor: "white"
    property color activeColor: "#89b4fa"
    property color dangerColor: "#f38ba8"
    property color subtleColor: "#a0a0a0"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)

    // Override any of these if your setup uses different tools.
    property string lockCommand: "hyprlock"
    property string logoutCommand: "hyprctl dispatch exit"
    property string suspendCommand: "systemctl suspend"
    property string rebootCommand: "systemctl reboot"
    property string shutdownCommand: "systemctl poweroff"

    signal requestClose()

    // Sizing hint for islandBackground.targetWidth/targetHeight
    readonly property real menuWidth: 400
    readonly property real menuHeight: 130

    // Index of the item currently "armed" (needs a second Enter to
    // actually fire). -1 means nothing armed. Selecting a different
    // item, or Escape, disarms it.
    property int armedIndex: -1

    ListModel {
        id: actionModel
        ListElement { key: "lock";     label: "Lock";     glyph: "\u{1F512}"; danger: false }
        ListElement { key: "suspend";  label: "Sleep";     glyph: "\u{1F319}"; danger: false }
        ListElement { key: "logout";   label: "Log Out";  glyph: "\u{23CF}";  danger: false }
        ListElement { key: "reboot";   label: "Restart";  glyph: "\u{27F3}";  danger: true }
        ListElement { key: "shutdown"; label: "Shut Down"; glyph: "\u{23FB}"; danger: true }
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
    }

    function commandFor(key) {
        switch (key) {
        case "lock": return root.lockCommand
        case "suspend": return root.suspendCommand
        case "logout": return root.logoutCommand
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
        spacing: 10

        Text {
            text: "Power"
            color: root.textColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignHCenter
        }

        ListView {
            id: row
            Layout.fillWidth: true
            Layout.fillHeight: true

            orientation: ListView.Horizontal
            model: actionModel
            spacing: 10
            clip: false

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 38
            preferredHighlightEnd: width / 2 + 38
            highlightMoveDuration: 220

            delegate: Item {
                id: delegateRoot
                width: 70
                height: row.height

                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isArmed: root.armedIndex === index

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: delegateRoot.isCurrent ? 58 : 48
                        height: delegateRoot.isCurrent ? 58 : 48
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: delegateRoot.isArmed
                               ? Qt.rgba(root.dangerColor.r, root.dangerColor.g, root.dangerColor.b, 0.22)
                               : root.backgroundColor
                        border.width: delegateRoot.isCurrent ? 2 : 0
                        border.color: delegateRoot.isArmed ? root.dangerColor : root.activeColor
                        opacity: delegateRoot.isCurrent ? 1.0 : 0.55

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: model.glyph
                            font.pixelSize: 20
                            color: root.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                row.currentIndex = index
                                root.activateIndex(index)
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
                    }
                }
            }
        }
    }
}
