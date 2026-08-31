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
    implicitHeight: 336 

    // ============================================================
    // STATE PROPERTIES & SIGNALS
    // ============================================================
    property string currentSubView: "main" // "main", "wifi", "bt"

    property bool wifiEnabled: false
    property string wifiSsid: "Disconnected"
    
    property bool btEnabled: false
    property string btDevice: "Disconnected"

    property string batteryPercent: "100%"
    property bool isCharging: false
    
    property real displayBrightness: 0
    signal brightnessChanged(real value)

    // ============================================================
    // DATA MODELS
    // ============================================================
    ListModel { id: wifiModel }
    ListModel { id: btModel }

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
        command: ["sh", "-c", "awk '{print int($0)}' /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 && cat /sys/class/power_supply/BAT*/status | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text).trim().split("\n");
                if (lines.length >= 1 && lines[0] !== "") dashboardRoot.batteryPercent = lines[0] + "%";
                if (lines.length >= 2) dashboardRoot.isCharging = (lines[1] === "Charging");
            }
        }
    }

    Process {
        id: wifiListProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list | grep -v '^:$' | head -n 15"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiModel.clear()
                var lines = String(text).trim().split('\n')
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var parts = lines[i].split(':');
                    if (parts.length >= 3 && parts[1] !== "") {
                        wifiModel.append({ "inUse": parts[0] === "*", "ssid": parts[1], "signal": parseInt(parts[2]) || 0 })
                    }
                }
            }
        }
    }

    Process {
        id: btListProc
        command: ["sh", "-c", "bluetoothctl devices | head -n 15"]
        stdout: StdioCollector {
            onStreamFinished: {
                btModel.clear()
                var lines = String(text).trim().split('\n')
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var parts = lines[i].split(' ');
                    if (parts.length >= 3) {
                        var name = parts.slice(2).join(' ');
                        var mac = parts[1];
                        btModel.append({ "mac": mac, "name": name, "connected": dashboardRoot.btDevice === name })
                    }
                }
            }
        }
    }

    Process { id: wifiToggleProc; property bool targetState: false; command: ["nmcli", "radio", "wifi", targetState ? "on" : "off"]; onExited: wifiProc.running = true }
    Process { id: btToggleProc; property bool targetState: false; command: ["rfkill", targetState ? "unblock" : "block", "bluetooth"]; onExited: btProc.running = true }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: wifiProc.running = true; Component.onCompleted: wifiProc.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProc.running = true; Component.onCompleted: btProc.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true; Component.onCompleted: batProc.running = true }
    
    // Sub-view list pollers
    Timer { interval: 5000; running: dashboardRoot.currentSubView === "wifi"; repeat: true; onTriggered: wifiListProc.running = true; onRunningChanged: { if(running) wifiListProc.running = true } }
    Timer { interval: 5000; running: dashboardRoot.currentSubView === "bt"; repeat: true; onTriggered: btListProc.running = true; onRunningChanged: { if(running) btListProc.running = true } }

    // ============================================================
    // VIEW CONTROLLER
    // ============================================================
    Item {
        anchors.fill: parent
        clip: true // Prevents sliding views from rendering outside the dashboard

        // ------------------------------------------------------------
        // MAIN VIEW
        // ------------------------------------------------------------
        Item {
            id: mainView
            width: parent.width
            height: parent.height
            x: dashboardRoot.currentSubView === "main" ? 0 : (dashboardRoot.currentSubView === "wifi" ? -width : -width)

            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16 
                spacing: 0

                // Header (Time, Date, Battery)
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

                Item { Layout.preferredHeight: 12 }

                // Toggles Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    spacing: 16

                    // Wi-Fi Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 14 
                            
                            Rectangle {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                color: dashboardRoot.wifiEnabled ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.2)
                                Text { anchors.centerIn: parent; text: dashboardRoot.wifiEnabled ? "󰤨" : "󰤭"; color: "white"; font.family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Item { Layout.fillWidth: true } 
                            Rectangle {
                                Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
                                color: dashboardRoot.wifiEnabled ? "#34c759" : Qt.rgba(1, 1, 1, 0.2)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle { 
                                    width: 18; height: 18; radius: 9; color: "white"; anchors.verticalCenter: parent.verticalCenter 
                                    x: dashboardRoot.wifiEnabled ? 18 : 2
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dashboardRoot.wifiEnabled = !dashboardRoot.wifiEnabled; 
                                        wifiToggleProc.targetState = dashboardRoot.wifiEnabled;
                                        wifiToggleProc.running = true;
                                    }
                                }
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 14; height: 30
                            
                            // ISOLATED CLICK TARGET FOR SUB-MENU
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: dashboardRoot.currentSubView = "wifi"
                            }

                            RowLayout {
                                anchors.fill: parent; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: "Wi-Fi"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: dashboardRoot.wifiEnabled ? dashboardRoot.wifiSsid : "Off"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                Text { text: "󰅂"; color: dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; Layout.alignment: Qt.AlignVCenter }
                            }
                        }
                    }

                    // Bluetooth Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(1, 1, 1, 0.08)

                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 14
                            
                            Rectangle {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                color: dashboardRoot.btEnabled ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.2)
                                Text { anchors.centerIn: parent; text: dashboardRoot.btEnabled ? "󰂯" : "󰂲"; color: "white"; font.family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Item { Layout.fillWidth: true } 
                            Rectangle {
                                Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
                                color: dashboardRoot.btEnabled ? "#34c759" : Qt.rgba(1, 1, 1, 0.2)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle { 
                                    width: 18; height: 18; radius: 9; color: "white"; anchors.verticalCenter: parent.verticalCenter 
                                    x: dashboardRoot.btEnabled ? 18 : 2
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dashboardRoot.btEnabled = !dashboardRoot.btEnabled;
                                        btToggleProc.targetState = dashboardRoot.btEnabled;
                                        btToggleProc.running = true;
                                    }
                                }
                            }
                        }

                        Item {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 14; height: 30
                            
                            // ISOLATED CLICK TARGET FOR SUB-MENU
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: dashboardRoot.currentSubView = "bt"
                            }

                            RowLayout {
                                anchors.fill: parent; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: "Bluetooth"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: dashboardRoot.btEnabled ? dashboardRoot.btDevice : "Off"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                Text { text: "󰅂"; color: dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; Layout.alignment: Qt.AlignVCenter }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 12 }

                Rectangle { Layout.alignment: Qt.AlignHCenter; width: 32; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.2) }

                Item { Layout.preferredHeight: 12 }

                // Display Slider
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 68; radius: 18; color: Qt.rgba(1, 1, 1, 0.08)
                    Text { text: "Display"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.top: parent.top; anchors.left: parent.left; anchors.topMargin: 10; anchors.leftMargin: 14 }
                    Rectangle {
                        id: brightnessTrack; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12; anchors.bottomMargin: 10; height: 28; radius: 14; color: Qt.rgba(1, 1, 1, 0.1)
                        property real dragBrightness: dashboardRoot.displayBrightness
                        property real activeBrightness: brightnessMouse.pressed ? dragBrightness : dashboardRoot.displayBrightness
                        Rectangle {
                            width: Math.max(height, parent.width * brightnessTrack.activeBrightness); height: parent.height; radius: 14; color: dashboardRoot.activeColor
                            Behavior on width { NumberAnimation { duration: brightnessMouse.pressed ? 0 : 150; easing.type: Easing.OutCubic } }
                            Rectangle { width: parent.height; height: parent.height; radius: width / 2; anchors.right: parent.right; color: "white"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08) }
                        }
                        MouseArea {
                            id: brightnessMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => { if (pressed) { brightnessTrack.dragBrightness = Math.max(0.01, Math.min(1, mouse.x / width)); dashboardRoot.brightnessChanged(brightnessTrack.dragBrightness) } }
                            onPressed: (mouse) => { brightnessTrack.dragBrightness = Math.max(0.01, Math.min(1, mouse.x / width)); dashboardRoot.brightnessChanged(brightnessTrack.dragBrightness) }
                        }
                    }
                }

                Item { Layout.preferredHeight: 10 }

                // Sound Slider
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 68; radius: 18; color: Qt.rgba(1, 1, 1, 0.08)
                    Text { text: "Sound"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.top: parent.top; anchors.left: parent.left; anchors.topMargin: 10; anchors.leftMargin: 14 }
                    Rectangle {
                        id: volumeTrack; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12; anchors.bottomMargin: 10; height: 28; radius: 14; color: Qt.rgba(1, 1, 1, 0.1)
                        property real backendVol: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volume !== undefined ? Pipewire.defaultAudioSink.audio.volume : 0
                        property real dragVol: backendVol
                        property real activeVol: volMouse.pressed ? dragVol : backendVol
                        Rectangle {
                            width: Math.max(height, parent.width * volumeTrack.activeVol); height: parent.height; radius: 14; color: dashboardRoot.activeColor
                            Behavior on width { NumberAnimation { duration: volMouse.pressed ? 0 : 150; easing.type: Easing.OutCubic } }
                            Rectangle { width: parent.height; height: parent.height; radius: width / 2; anchors.right: parent.right; color: "white"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08) }
                        }
                        MouseArea {
                            id: volMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => { if (pressed && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) { volumeTrack.dragVol = Math.max(0, Math.min(1, mouse.x / width)); Pipewire.defaultAudioSink.audio.volume = volumeTrack.dragVol } }
                            onPressed: (mouse) => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) { volumeTrack.dragVol = Math.max(0, Math.min(1, mouse.x / width)); Pipewire.defaultAudioSink.audio.volume = volumeTrack.dragVol } }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // WI-FI SUB-VIEW
        // ------------------------------------------------------------
        Rectangle {
            id: wifiView
            width: parent.width; height: parent.height
            color: "transparent"
            x: dashboardRoot.currentSubView === "wifi" ? 0 : width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "main" }
                    }
                    Text { text: "Wi-Fi Networks"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: wifiModel
                    spacing: 8
                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; radius: 12
                        color: inUse ? Qt.rgba(0.2, 0.5, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            // In the future, attach a process to trigger connection here
                            onClicked: console.log("Requested connection to: " + ssid)
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12
                            Text { text: "󰤨"; color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: ssid; color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: inUse ? Font.Bold : Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: ""; color: "#3b82f6"; font.family: "JetBrainsMono Nerd Font"; visible: inUse }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // BLUETOOTH SUB-VIEW
        // ------------------------------------------------------------
        Rectangle {
            id: btView
            width: parent.width; height: parent.height
            color: "transparent"
            x: dashboardRoot.currentSubView === "bt" ? 0 : width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "main" }
                    }
                    Text { text: "Bluetooth Devices"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: btModel
                    spacing: 8
                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; radius: 12
                        color: connected ? Qt.rgba(0.2, 0.5, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: console.log("Requested connection to BT MAC: " + mac)
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12
                            Text { text: "󰂯"; color: connected ? "#3b82f6" : dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: name; color: connected ? "#3b82f6" : dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: connected ? Font.Bold : Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: ""; color: "#3b82f6"; font.family: "JetBrainsMono Nerd Font"; visible: connected }
                        }
                    }
                }
            }
        }
    }
}
