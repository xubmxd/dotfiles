import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: dashboardRoot

    property color textColor: "#ffffff"
    property color activeColor: "#ffffff"
    property color backgroundColor: "#000000"
    property color subtleColor: "#888888"

    implicitWidth: 380
    implicitHeight: 336 // Mathematically perfected height based on the exact spacing below

    // ============================================================
    // STATE PROPERTIES & SIGNALS
    // ============================================================
    property bool wifiEnabled: false
    property string wifiSsid: "Disconnected"
    
    property bool btEnabled: false
    property string btDevice: "Disconnected"

    property string batteryPercent: "100%"
    property bool isCharging: false
    
    property real displayBrightness: 0
    signal brightnessChanged(real value)

    // ============================================================
    // SYSTEM POLLING PROCESSES
    // ============================================================
    
    Process {
        id: wifiProc
        command: ["sh", "-c", "echo \"$(nmcli -t -f WIFI radio 2>/dev/null):$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var res = String(text).trim().split(":");
                dashboardRoot.wifiEnabled = (res[0] === "enabled");
                dashboardRoot.wifiSsid = (res[1] && res[1] !== "") ? res[1] : "Disconnected";
            }
        }
    }

    Process {
        id: btProc
        command: ["sh", "-c", "echo \"$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'enabled' || echo 'disabled'):$(bluetoothctl info 2>/dev/null | grep 'Name:' | cut -d: -f2 | xargs)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var res = String(text).trim().split(":");
                dashboardRoot.btEnabled = (res[0] === "enabled");
                dashboardRoot.btDevice = (res[1] && res[1] !== "") ? res[1] : "Disconnected";
            }
        }
    }

    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity | head -n 1 && cat /sys/class/power_supply/BAT*/status | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text).trim().split("\n");
                if (lines.length >= 1 && lines[0] !== "") dashboardRoot.batteryPercent = lines[0] + "%";
                if (lines.length >= 2) dashboardRoot.isCharging = (lines[1] === "Charging");
            }
        }
    }

    Process { id: wifiToggleProc; property bool targetState: false; command: ["nmcli", "radio", "wifi", targetState ? "on" : "off"]; onExited: wifiProc.running = true }
    Process { id: btToggleProc; property bool targetState: false; command: ["rfkill", targetState ? "unblock" : "block", "bluetooth"]; onExited: btProc.running = true }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: wifiProc.running = true; Component.onCompleted: wifiProc.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProc.running = true; Component.onCompleted: btProc.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true; Component.onCompleted: batProc.running = true }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 
        spacing: 0

        // ============================================================
        // HEADER (Time, Date, Battery)
        // ============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            
            Text {
                id: timeText
                font.family: "sans-serif"
                font.pixelSize: 22
                font.weight: Font.Bold
                color: dashboardRoot.textColor
            }
            
            Text {
                id: dateText
                font.family: "sans-serif"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: dashboardRoot.subtleColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 2
                Layout.leftMargin: 4
            }
            
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: {
                    timeText.text = new Date().toLocaleTimeString(Qt.locale(), "h:mm ap").toLowerCase()
                    dateText.text = new Date().toLocaleDateString(Qt.locale(), "ddd, MMM d")
                }
                Component.onCompleted: triggered()
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                Text { text: "󰂄"; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; visible: dashboardRoot.isCharging }
                Text { text: dashboardRoot.batteryPercent; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                Text { text: dashboardRoot.isCharging ? "󰂄" : "󰁹"; color: "#22c55e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Item { Layout.preferredHeight: 12 } // Gap

        // ============================================================
        // TOGGLES ROW (Wi-Fi & Bluetooth)
        // ============================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 92 // Increased slightly to give the elements breathing room
            spacing: 16 // Mathematically matches the outer margins

            // ------------------ Wi-Fi Card ------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.08)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardRoot.wifiEnabled = !dashboardRoot.wifiEnabled; 
                        wifiToggleProc.targetState = dashboardRoot.wifiEnabled;
                        wifiToggleProc.running = true;
                    }
                }

                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14 // Consistent internal padding
                    
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                        color: dashboardRoot.wifiEnabled ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.2)
                        Text { anchors.centerIn: parent; text: dashboardRoot.wifiEnabled ? "󰤨" : "󰤭"; color: "white"; font.family: "JetBrainsMono Nerd Font" }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    Item { Layout.fillWidth: true } // Dynamically pushes the switch to the right
                    
                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
                        color: dashboardRoot.wifiEnabled ? "#34c759" : Qt.rgba(1, 1, 1, 0.2)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle { 
                            width: 18; height: 18; radius: 9; color: "white"
                            anchors.verticalCenter: parent.verticalCenter 
                            x: dashboardRoot.wifiEnabled ? 18 : 2
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 8
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Wi-Fi"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: dashboardRoot.wifiEnabled ? dashboardRoot.wifiSsid : "Off"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Text { text: "󰅂"; color: dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; Layout.alignment: Qt.AlignVCenter }
                }
            }

            // ------------------ Bluetooth Card ------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.08)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardRoot.btEnabled = !dashboardRoot.btEnabled;
                        btToggleProc.targetState = dashboardRoot.btEnabled;
                        btToggleProc.running = true;
                    }
                }

                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                        color: dashboardRoot.btEnabled ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.2)
                        Text { anchors.centerIn: parent; text: dashboardRoot.btEnabled ? "󰂯" : "󰂲"; color: "white"; font.family: "JetBrainsMono Nerd Font" }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    Item { Layout.fillWidth: true } // Dynamically pushes the switch to the right
                    
                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
                        color: dashboardRoot.btEnabled ? "#34c759" : Qt.rgba(1, 1, 1, 0.2)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle { 
                            width: 18; height: 18; radius: 9; color: "white"
                            anchors.verticalCenter: parent.verticalCenter 
                            x: dashboardRoot.btEnabled ? 18 : 2
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 8
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Bluetooth"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: dashboardRoot.btEnabled ? dashboardRoot.btDevice : "Off"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Text { text: "󰅂"; color: dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; Layout.alignment: Qt.AlignVCenter }
                }
            }
        }

        Item { Layout.preferredHeight: 12 } // Gap

        // ============================================================
        // PILL GRABBER / SEPARATOR
        // ============================================================
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 32
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.2)
        }

        Item { Layout.preferredHeight: 12 } // Gap

        // ============================================================
        // DISPLAY SLIDER
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 18
            color: Qt.rgba(1, 1, 1, 0.08)

            Text {
                text: "Display"
                color: dashboardRoot.textColor
                font.family: "sans-serif"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 10
                anchors.leftMargin: 14
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.bottomMargin: 10
                height: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.1)

                Rectangle {
                    width: Math.max(height, parent.width * dashboardRoot.displayBrightness)
                    height: parent.height
                    radius: 14
                    color: dashboardRoot.activeColor
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    
                    Rectangle {
                        width: parent.height
                        height: parent.height
                        radius: width / 2
                        anchors.right: parent.right
                        color: "white"
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.08)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (mouse) => {
                        if (pressed) dashboardRoot.brightnessChanged(Math.max(0, Math.min(1, mouse.x / width)))
                    }
                    onPressed: (mouse) => {
                        dashboardRoot.brightnessChanged(Math.max(0, Math.min(1, mouse.x / width)))
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 10 } // Gap

        // ============================================================
        // SOUND SLIDER
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 18
            color: Qt.rgba(1, 1, 1, 0.08)

            Text {
                text: "Sound"
                color: dashboardRoot.textColor
                font.family: "sans-serif"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 10
                anchors.leftMargin: 14
            }
            
            Rectangle {
                id: volumeTrack
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.bottomMargin: 10
                height: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.1)

                property real vol: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volume !== undefined ? Pipewire.defaultAudioSink.audio.volume : 0

                Rectangle {
                    width: Math.max(height, parent.width * parent.vol)
                    height: parent.height
                    radius: 14
                    color: dashboardRoot.activeColor
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    
                    Rectangle {
                        width: parent.height
                        height: parent.height
                        radius: width / 2
                        anchors.right: parent.right
                        color: "white"
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.08)
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (mouse) => {
                        if (pressed && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }
                    }
                    onPressed: (mouse) => {
                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                        }
                    }
                }
            }
        }
    }
}
