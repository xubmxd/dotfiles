import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: "white"
    property color activeColor: "#89b4fa"
    property color subtleColor: "#a0a0a0"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)

    // "setup" | "compact" | "expanded"
    property string mode: "compact"

    readonly property real setupWidth: 320
    readonly property real setupHeight: 254
    readonly property real compactImplicitWidth: 150

    property int totalSeconds: 300
    property int remainingSeconds: 300
    property bool running: false
    property bool finished: false
    readonly property bool hasSession: running || finished

    signal requestClose()
    signal requestExpand()
    signal timerFinished()

    function formatTime(s) {
        var m = Math.floor(s / 60)
        var sec = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function start() {
        remainingSeconds = totalSeconds
        running = true
        finished = false
    }

    function pause() { running = false }
    function resume() { if (!finished) running = true }

    function addMinute() {
        totalSeconds += 60
        if (!finished) remainingSeconds += 60
    }

    function cancel() {
        running = false
        finished = false
        remainingSeconds = totalSeconds
        requestClose()
    }

    function applyCustomDuration() {
        var h = parseInt(customHoursInput.text) || 0
        var m = parseInt(customMinutesInput.text) || 0
        var total = h * 3600 + m * 60
        if (total <= 0)
            return
        root.totalSeconds = total
        root.remainingSeconds = total
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds -= 1
            }
            if (root.remainingSeconds <= 0) {
                root.running = false
                root.finished = true
                root.timerFinished()
            }
        }
    }

    // ---------------- Setup ----------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14
        visible: root.mode === "setup"

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Set Timer"
                color: root.textColor
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Text {
                text: "\u2715"
                color: root.subtleColor
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestClose()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [1, 5, 10, 15, 20, 30]

                delegate: Rectangle {
                    required property int modelData

                    Layout.fillWidth: true
                    height: 34
                    radius: 10
                    color: root.totalSeconds === modelData * 60
                        ? root.activeColor
                        : root.backgroundColor

                    Text {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        color: root.totalSeconds === modelData * 60 ? "black" : root.textColor
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.totalSeconds = modelData * 60
                            root.remainingSeconds = root.totalSeconds
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Custom"
                color: root.subtleColor
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 34
                radius: 10
                color: root.backgroundColor
                border.width: customHoursInput.activeFocus ? 1 : 0
                border.color: root.activeColor

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3

                    TextInput {
                        id: customHoursInput
                        Layout.preferredWidth: 16
                        text: "0"
                        color: root.textColor
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignRight
                        selectByMouse: true
                        clip: true
                        validator: IntValidator { bottom: 0; top: 23 }
                        onEditingFinished: root.applyCustomDuration()
                    }

                    Text {
                        text: "h"
                        color: root.subtleColor
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: customHoursInput.forceActiveFocus()
                }
            }

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 34
                radius: 10
                color: root.backgroundColor
                border.width: customMinutesInput.activeFocus ? 1 : 0
                border.color: root.activeColor

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3

                    TextInput {
                        id: customMinutesInput
                        Layout.preferredWidth: 16
                        text: "5"
                        color: root.textColor
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignRight
                        selectByMouse: true
                        clip: true
                        validator: IntValidator { bottom: 0; top: 59 }
                        onEditingFinished: root.applyCustomDuration()
                    }

                    Text {
                        text: "m"
                        color: root.subtleColor
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: customMinutesInput.forceActiveFocus()
                }
            }

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 34
                radius: 10
                color: root.activeColor

                Text {
                    anchors.centerIn: parent
                    text: "Set"
                    color: "black"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        customHoursInput.focus = false
                        customMinutesInput.focus = false
                        root.applyCustomDuration()
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 12
            color: root.activeColor

            Text {
                anchors.centerIn: parent
                text: "Start " + root.formatTime(root.totalSeconds)
                color: "black"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.start()
            }
        }
    }

    // ---------------- Compact pill ----------------
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: root.mode === "compact"

        Text {
            text: root.finished ? "\u23F0" : "\u23F1"
            color: root.finished ? "#ef4444" : root.activeColor
            font.pixelSize: 14
        }

        Text {
            text: root.finished ? "Time's up" : root.formatTime(root.remainingSeconds)
            color: root.textColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.mode === "compact"
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestExpand()
    }

    // ---------------- Expanded ----------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        visible: root.mode === "expanded"

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.finished ? "Time's up" : "Timer"
                color: root.finished ? "#ef4444" : root.subtleColor
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            Text {
                text: "\u2715"
                color: root.subtleColor
                font.pixelSize: 14

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancel()
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.formatTime(root.remainingSeconds)
            color: root.textColor
            font.pixelSize: 40
            font.weight: Font.Bold
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: root.backgroundColor

            Rectangle {
                height: parent.height
                radius: 2
                color: root.activeColor
                width: root.totalSeconds > 0
                    ? parent.width * (root.remainingSeconds / root.totalSeconds)
                    : 0

                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 10
                color: root.backgroundColor

                Text {
                    anchors.centerIn: parent
                    text: "+1m"
                    color: root.textColor
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addMinute()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 10
                color: root.activeColor

                Text {
                    anchors.centerIn: parent
                    text: root.running ? "Pause" : "Resume"
                    color: "black"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.running ? root.pause() : root.resume()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 10
                color: Qt.rgba(0.94, 0.27, 0.27, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: "#ef4444"
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancel()
                }
            }
        }
    }
}
