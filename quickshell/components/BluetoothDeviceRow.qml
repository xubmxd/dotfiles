import QtQuick
import QtQuick.Layouts
import "../services"

// ================================================================
// BLUETOOTH DEVICE ROW
// ----------------------------------------------------------------
// A single row in the Bluetooth manager list (Connected / My Devices /
// Other Devices sections). Tapping the row body performs the Apple-style
// primary action (pair / connect / disconnect); tapping the trailing
// info button opens the device's detail sheet instead.
// ================================================================

Rectangle {
    id: root

    property var device: null
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#3b82f6"

    signal openDetail()

    // Local, self-clearing "busy" flag. BlueZ exposes `pairing` for the
    // pairing handshake, but a plain connect() on an already-paired
    // device has no exposed "connecting" bool — so we show a brief busy
    // state ourselves and clear it as soon as the device's real state
    // changes (or after a timeout, in case the attempt silently fails).
    property bool busy: false

    height: 48
    radius: 12
    color: (device && device.connected) ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
                                         : Qt.rgba(1, 1, 1, 0.05)

    Behavior on color { ColorAnimation { duration: 150 } }

    Connections {
        target: root.device
        function onConnectedChanged() { root.busy = false }
        function onPairedChanged() { root.busy = false }
        function onPairingChanged() { if (root.device && !root.device.pairing) root.busy = false }
    }

    Timer { id: busyTimeout; interval: 8000; onTriggered: root.busy = false }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 40
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.device || root.busy) return
            root.busy = true
            busyTimeout.restart()
            BluetoothService.toggleDevice(root.device)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 40
        spacing: 10

        Text {
            text: root.device ? BluetoothService.glyphFor(root.device) : ""
            color: (root.device && root.device.connected) ? root.accentColor : root.textColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: root.device ? root.device.name : ""
                color: (root.device && root.device.connected) ? root.accentColor : root.textColor
                font.family: "sans-serif"; font.pixelSize: 13
                font.weight: (root.device && root.device.connected) ? Font.Bold : Font.Medium
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: {
                    if (!root.device) return ""
                    if (root.busy || root.device.pairing) return "Pairing…"
                    if (root.device.connected && root.device.batteryAvailable)
                        return "Connected · " + Math.round(root.device.battery * 100) + "%"
                    return BluetoothService.statusFor(root.device)
                }
                color: root.subtleColor
                font.family: "sans-serif"; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        // Small spinner while a connect/pair attempt is in flight.
        Rectangle {
            width: 12; height: 12; radius: 6; color: "transparent"
            border.color: root.subtleColor; border.width: 2
            visible: root.busy || (root.device && root.device.pairing)
            RotationAnimator on rotation {
                running: root.busy || (root.device && root.device.pairing)
                from: 0; to: 360; duration: 800; loops: Animation.Infinite
            }
        }
    }

    // Info / detail button — sits outside the primary tap area so it
    // never triggers a connect/disconnect by accident.
    Rectangle {
        width: 28; height: 28; radius: 14
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "\u{f0142}"
            color: root.subtleColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openDetail()
        }
    }
}
