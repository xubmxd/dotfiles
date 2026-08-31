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

    // Reset sub-view back to main whenever the dashboard is closed/hidden
    onVisibleChanged: {
        if (!visible) {
            currentSubView = "main"
            wifiConnectionState = "password"
            targetWifiSsid = ""
            wifiConnectionStatus = ""
        }
    }

    signal requestClose()

    // ============================================================
    // STATE PROPERTIES & SIGNALS
    // ============================================================
    property string currentSubView: "main" // "main", "wifi", "bt", "wifi-password"
    property string wifiConnectionState: "password" // "password", "connecting", "success", "error"
    property string targetWifiSsid: ""
    property string wifiConnectionStatus: ""

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
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list | grep -v '^:$' | head -n 15"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiModel.clear()
                var lines = String(text).trim().split('\n')
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var parts = lines[i].split(':');
                    if (parts.length >= 4 && parts[1] !== "") {
                        var isSecured = parts[2] !== "" && parts[2] !== "--";
                        wifiModel.append({ 
                            "inUse": parts[0] === "*", 
                            "ssid": parts[1], 
                            "secured": isSecured,
                            "signal": parseInt(parts[3]) || 0 
                        })
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

    // Real Connection Process with Exit Code Detection
    Process {
        id: wifiConnectProc
        property string ssidName: ""
        property string wifiPassword: ""
        command: wifiPassword !== "" ? ["nmcli", "device", "wifi", "connect", ssidName, "password", wifiPassword] : ["nmcli", "device", "wifi", "connect", ssidName]
        
        onExited: (exitCode, exitStatus) => {
            dashboardRoot.wifiConnectionStatus = "";
            wifiProc.running = true;
            if (exitCode === 0) {
                dashboardRoot.wifiConnectionState = "success";
                successTimer.restart();
            } else {
                dashboardRoot.wifiConnectionState = "error";
            }
        }
    }

    Timer {
        id: successTimer
        interval: 1800
        repeat: false
        onTriggered: {
            dashboardRoot.wifiConnectionState = "password";
            dashboardRoot.currentSubView = "main";
            dashboardRoot.requestClose();
        }
    }

    Process { id: wifiToggleProc; property bool targetState: false; command: ["nmcli", "radio", "wifi", targetState ? "on" : "off"]; onExited: wifiProc.running = true }
    Process { id: btToggleProc; property bool targetState: false; command: ["rfkill", targetState ? "unblock" : "block", "bluetooth"]; onExited: btProc.running = true }
    Process { id: btConnectProc; property string macAddress: ""; command: ["bluetoothctl", "connect", macAddress]; onExited: btProc.running = true }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: wifiProc.running = true; Component.onCompleted: wifiProc.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProc.running = true; Component.onCompleted: btProc.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true; Component.onCompleted: batProc.running = true }
    
    Timer { interval: 5000; running: dashboardRoot.currentSubView === "wifi"; repeat: true; onTriggered: wifiListProc.running = true; onRunningChanged: { if(running) { nmcliScanProc.running = true; wifiListProc.running = true } } }
    Process { id: nmcliScanProc; command: ["nmcli", "device", "wifi", "rescan"] }

    Timer { interval: 5000; running: dashboardRoot.currentSubView === "bt"; repeat: true; onTriggered: btListProc.running = true; onRunningChanged: { if(running) btListProc.running = true } }

    // ============================================================
    // VIEW CONTROLLER
    // ============================================================
    Item {
        anchors.fill: parent
        clip: true 

        // ------------------------------------------------------------
        // MAIN VIEW
        // ------------------------------------------------------------
        Item {
            id: mainView
            width: parent.width; height: parent.height
            visible: dashboardRoot.currentSubView === "main" || x > -width
            x: dashboardRoot.currentSubView === "main" ? 0 : -width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 0

                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    Text { id: timeText; font.family: "sans-serif"; font.pixelSize: 22; font.weight: Font.Bold; color: dashboardRoot.textColor }
                    Text { id: dateText; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Medium; color: dashboardRoot.subtleColor; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 2; Layout.leftMargin: 4 }
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
                        spacing: 4; Layout.alignment: Qt.AlignVCenter
                        Text { text: "󰂄"; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; visible: dashboardRoot.isCharging }
                        Text { text: dashboardRoot.batteryPercent; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: dashboardRoot.isCharging ? "󰂄" : "󰁹"; color: "#22c55e"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Item { Layout.preferredHeight: 12 }

                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 92; spacing: 16

                    // Wi-Fi Card
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 18; color: Qt.rgba(1, 1, 1, 0.08)
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
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "wifi" }
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
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 18; color: Qt.rgba(1, 1, 1, 0.08)
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
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "bt" }
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
            width: parent.width; height: parent.height; color: "transparent"
            visible: dashboardRoot.currentSubView === "wifi"
            x: dashboardRoot.currentSubView === "wifi" ? 0 : width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16

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
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: wifiModel; spacing: 8
                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; radius: 12
                        color: inUse ? Qt.rgba(0.2, 0.5, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (secured && !inUse) {
                                    dashboardRoot.targetWifiSsid = ssid;
                                    dashboardRoot.wifiConnectionState = "password";
                                    dashboardRoot.currentSubView = "wifi-password";
                                } else {
                                    dashboardRoot.wifiConnectionState = "connecting";
                                    dashboardRoot.targetWifiSsid = ssid;
                                    dashboardRoot.currentSubView = "wifi-password";
                                    wifiConnectProc.ssidName = ssid;
                                    wifiConnectProc.wifiPassword = "";
                                    wifiConnectProc.running = true;
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12
                            Text { text: secured ? "󰌾" : "󰤨"; color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: ssid; color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: inUse ? Font.Bold : Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: ""; color: "#3b82f6"; font.family: "JetBrainsMono Nerd Font"; visible: inUse }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // WI-FI FLOW & DYNAMIC ISLAND STATUS SUB-VIEW
        // ------------------------------------------------------------
        FocusScope {
            id: wifiFlowView
            width: parent.width; height: parent.height
            visible: dashboardRoot.currentSubView === "wifi-password"
            x: dashboardRoot.currentSubView === "wifi-password" ? 0 : width
            focus: visible && dashboardRoot.wifiConnectionState === "password"
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            onVisibleChanged: {
                if (visible && dashboardRoot.wifiConnectionState === "password") {
                    passwordInput.forceActiveFocus();
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 20

                // State 1: Password Entry Form
                Item {
                    id: passwordFormContainer
                    anchors.fill: parent
                    opacity: dashboardRoot.wifiConnectionState === "password" ? 1 : 0
                    scale: dashboardRoot.wifiConnectionState === "password" ? 1 : 0.95
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent; spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                                Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "wifi" }
                            }
                            Text { text: "Enter Password"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }
                        }

                        Text {
                            text: "Network: " + dashboardRoot.targetWifiSsid
                            color: dashboardRoot.subtleColor
                            font.family: "sans-serif"; font.pixelSize: 13
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: passwordInput.forceActiveFocus()
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent; anchors.margins: 12
                                color: dashboardRoot.textColor
                                font.family: "sans-serif"; font.pixelSize: 14
                                echoMode: TextInput.Password
                                focus: dashboardRoot.wifiConnectionState === "password"

                                onActiveFocusChanged: {
                                    console.log("[WiFi Password] activeFocus:", activeFocus)
                                }

                                Text {
                                    text: "Enter network password..."
                                    color: dashboardRoot.subtleColor
                                    font.family: "sans-serif"; font.pixelSize: 14
                                    visible: !passwordInput.text && !passwordInput.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                            color: "#3b82f6"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: "white"
                                font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: dashboardRoot.wifiConnectionState === "password" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: dashboardRoot.wifiConnectionState === "password"
                                onClicked: {
                                    dashboardRoot.wifiConnectionState = "connecting";
                                    wifiConnectProc.ssidName = dashboardRoot.targetWifiSsid;
                                    wifiConnectProc.wifiPassword = passwordInput.text;
                                    wifiConnectProc.running = true;
                                    passwordInput.text = ""; // Clear password immediately from memory
                                }
                            }
                        }
                    }
                }

                // States 2, 3, 4: Dynamic Island System Status Display (Connecting, Success, Error)
                Item {
                    id: statusDisplayContainer
                    anchors.fill: parent
                    opacity: dashboardRoot.wifiConnectionState !== "password" ? 1 : 0
                    scale: dashboardRoot.wifiConnectionState !== "password" ? 1 : 1.05
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 36; height: 36

                            // Spinner for Connecting state
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30; height: 30; radius: 15
                                color: "transparent"
                                border.color: "#3b82f6"
                                border.width: 3
                                visible: dashboardRoot.wifiConnectionState === "connecting"

                                RotationAnimator on rotation {
                                    running: dashboardRoot.wifiConnectionState === "connecting"
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }

                            // Checkmark for Success state
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#22c55e"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold
                                visible: dashboardRoot.wifiConnectionState === "success"
                            }

                            // Exclamation for Error state
                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: "#ef4444"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold
                                visible: dashboardRoot.wifiConnectionState === "error"
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                if (dashboardRoot.wifiConnectionState === "connecting") return "Connecting...";
                                if (dashboardRoot.wifiConnectionState === "success") return "Connected";
                                if (dashboardRoot.wifiConnectionState === "error") return "Connection Failed";
                                return "";
                            }
                            color: dashboardRoot.textColor
                            font.family: "sans-serif"; font.pixelSize: 15; font.weight: Font.Bold
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: dashboardRoot.targetWifiSsid
                            color: dashboardRoot.subtleColor
                            font.family: "sans-serif"; font.pixelSize: 12
                        }

                        // Try Again Action on Error
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 6
                            width: 90; height: 30; radius: 15
                            color: Qt.rgba(1, 1, 1, 0.15)
                            visible: dashboardRoot.wifiConnectionState === "error"

                            Text {
                                anchors.centerIn: parent
                                text: "Try Again"
                                color: dashboardRoot.textColor
                                font.family: "sans-serif"; font.pixelSize: 12; font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dashboardRoot.wifiConnectionState = "password";
                                    passwordInput.text = "";
                                    passwordInput.forceActiveFocus();
                                }
                            }
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
            width: parent.width; height: parent.height; color: "transparent"
            visible: dashboardRoot.currentSubView === "bt"
            x: dashboardRoot.currentSubView === "bt" ? 0 : width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16

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
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: btModel; spacing: 8
                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; radius: 12
                        color: connected ? Qt.rgba(0.2, 0.5, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                btConnectProc.macAddress = mac;
                                btConnectProc.running = true;
                            }
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
