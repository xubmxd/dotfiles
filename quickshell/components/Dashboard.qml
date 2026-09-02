import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../services"

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
            selectedBtDevice = null
        }
    }

    signal requestClose()

    // ============================================================
    // STATE PROPERTIES & SIGNALS
    // ============================================================
    property string currentSubView: "main" // "main", "wifi", "wifi-password", "wifi-detail", "bt", "bt-detail"

    // Z-depth of each sub-view for the 3D pop/push transition — views
    // deeper than the active one swallow toward the center, views
    // shallower than the active one push back.
    function depthFor(state) {
        switch (state) {
        case "wifi": case "bt": return 1
        case "wifi-detail": case "wifi-password": case "bt-detail": return 2
        default: return 0
        }
    }
    readonly property int activeDepth: depthFor(currentSubView)
    property string wifiConnectionState: "password" // "password", "connecting", "success", "error"
    property string targetWifiSsid: ""
    property string wifiConnectionStatus: ""

    property bool wifiEnabled: false
    property string wifiSsid: "Disconnected"

    // Bluetooth is fully event-driven via BluetoothService (BlueZ/DBus) —
    // no polling needed. These simply mirror the service for the compact
    // card on the main view.
    readonly property bool btEnabled: BluetoothService.powered
    readonly property string btDevice: BluetoothService.summaryLabel
    property var selectedBtDevice: null

    // Turn Bluetooth discovery on only while the Bluetooth sub-view (or a
    // device's detail sheet) is actually open — mirrors macOS/iOS, which
    // only scans while the Bluetooth settings screen is visible.
    onCurrentSubViewChanged: {
        BluetoothService.setDiscovering(
            currentSubView === "bt" || currentSubView === "bt-detail")
    }

    property string batteryPercent: "100%"
    property bool isCharging: false
    
    property real displayBrightness: 0
    signal brightnessChanged(real value)

    // ============================================================
    // DATA MODELS
    // ============================================================
    ListModel { id: wifiModel }

    // Parses a single line of `nmcli -t` terse output into fields,
    // respecting nmcli's backslash-escaping of ":" inside field values
    // (e.g. SSIDs that themselves contain a colon). A naive split(':')
    // breaks on those — this doesn't.
    function nmcliSplit(line) {
        var fields = []
        var current = ""
        for (var i = 0; i < line.length; i++) {
            var ch = line[i]
            if (ch === '\\' && i + 1 < line.length) {
                current += line[i + 1]
                i++
            } else if (ch === ':') {
                fields.push(current)
                current = ""
            } else {
                current += ch
            }
        }
        fields.push(current)
        return fields
    }

    // Signal strength is communicated with opacity on the same verified
    // Wi-Fi glyph rather than swapping in separate "1/2/3 bar" icons —
    // Nerd Font codepoints for those vary by font version/build, so we
    // stick to the one glyph already confirmed to render in this project
    // (the same one used for the Wi-Fi card icon) to avoid tofu glyphs.
    readonly property string wifiGlyph: "\u{f0928}"

    function wifiSignalOpacity(signal) {
        if (signal >= 80) return 1.0
        if (signal >= 55) return 0.75
        if (signal >= 30) return 0.5
        return 0.35
    }

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

    // Lists nearby networks, de-duplicated by SSID (nmcli reports one row
    // per BSSID, so a single access point with multiple radios shows up
    // multiple times) keeping the strongest signal seen for each SSID —
    // matching how macOS/iOS present exactly one row per network.
    Process {
        id: wifiListProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(text).trim().split('\n')
                var bySsid = {}
                var order = []

                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var parts = dashboardRoot.nmcliSplit(lines[i]);
                    if (parts.length < 4 || parts[1] === "") continue;

                    var ssid = parts[1];
                    var inUse = parts[0] === "*";
                    var secured = parts[2] !== "" && parts[2] !== "--";
                    var signal = parseInt(parts[3]) || 0;

                    var existing = bySsid[ssid];
                    if (!existing) {
                        order.push(ssid);
                        bySsid[ssid] = { inUse: inUse, ssid: ssid, secured: secured, signal: signal };
                    } else {
                        existing.inUse = existing.inUse || inUse;
                        existing.secured = existing.secured || secured;
                        if (signal > existing.signal) existing.signal = signal;
                    }
                }

                // Strongest signal first, but the connected network always leads.
                order.sort(function (a, b) {
                    var ea = bySsid[a], eb = bySsid[b];
                    if (ea.inUse !== eb.inUse) return ea.inUse ? -1 : 1;
                    return eb.signal - ea.signal;
                });

                wifiModel.clear()
                for (var j = 0; j < order.length; j++) {
                    wifiModel.append(bySsid[order[j]]);
                }
            }
        }
    }

    // First connection attempt for a tapped network: no password supplied.
    // This lets already-known/saved networks (and open networks) connect
    // silently, exactly like macOS/iOS — the password form only appears
    // when the system actually needs a secret.
    Process {
        id: wifiQuickConnectProc
        property string ssidName: ""
        command: ["nmcli", "device", "wifi", "connect", ssidName]

        stdout: StdioCollector { id: quickConnectStdout }
        stderr: StdioCollector { id: quickConnectStderr }

        onExited: (exitCode, exitStatus) => {
            wifiProc.running = true;
            if (exitCode === 0) {
                dashboardRoot.wifiConnectionState = "success";
                successTimer.restart();
                return;
            }

            var output = (String(quickConnectStdout.text) + " " + String(quickConnectStderr.text)).toLowerCase();
            var needsSecret = output.indexOf("secret") !== -1
                || output.indexOf("password") !== -1
                || output.indexOf("key required") !== -1
                || output.indexOf("802-1x") !== -1;

            if (needsSecret) {
                dashboardRoot.wifiConnectionState = "password";
            } else {
                dashboardRoot.wifiConnectionState = "error";
            }
        }
    }

    // Explicit connection attempt with a password the user just typed.
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

    // Disconnects the active Wi-Fi connection without forgetting it.
    Process {
        id: wifiDisconnectProc
        property string ssidName: ""
        command: ["nmcli", "connection", "down", ssidName]
        onExited: {
            wifiProc.running = true;
            wifiListProc.running = true;
            dashboardRoot.currentSubView = "wifi";
        }
    }

    // Forgets a saved network's credentials entirely.
    Process {
        id: wifiForgetProc
        property string ssidName: ""
        command: ["nmcli", "connection", "delete", ssidName]
        onExited: {
            wifiProc.running = true;
            wifiListProc.running = true;
            dashboardRoot.currentSubView = "wifi";
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

    Timer { interval: 5000; running: true; repeat: true; onTriggered: wifiProc.running = true; Component.onCompleted: wifiProc.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true; Component.onCompleted: batProc.running = true }

    property bool wifiScanning: false
    Timer {
        interval: 6000
        running: dashboardRoot.currentSubView === "wifi"
        repeat: true
        onTriggered: { nmcliScanProc.running = true; wifiListProc.running = true }
        onRunningChanged: if (running) { nmcliScanProc.running = true; wifiListProc.running = true }
    }
    Process {
        id: nmcliScanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onRunningChanged: dashboardRoot.wifiScanning = running
    }

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

            readonly property bool isActive: dashboardRoot.currentSubView === "main"
            readonly property int myDepth: 0

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center

            transform: Rotation {
                origin.x: mainView.width / 2; origin.y: mainView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: mainView.isActive ? 0 : (mainView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

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
                                    onClicked: BluetoothService.setPowered(!BluetoothService.powered)
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

            readonly property bool isActive: dashboardRoot.currentSubView === "wifi"
            readonly property int myDepth: 1

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center

            transform: Rotation {
                origin.x: wifiView.width / 2; origin.y: wifiView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: wifiView.isActive ? 0 : (wifiView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "main" }
                    }
                    Text { text: "Wi-Fi Networks"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }

                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "transparent"
                        border.color: dashboardRoot.subtleColor; border.width: 2
                        visible: dashboardRoot.wifiScanning
                        RotationAnimator on rotation {
                            running: dashboardRoot.wifiScanning
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.alignment: Qt.AlignCenter
                    visible: !dashboardRoot.wifiEnabled || wifiModel.count === 0
                    spacing: 6

                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: dashboardRoot.wifiGlyph
                        opacity: !dashboardRoot.wifiEnabled ? 1 : 0.35
                        color: dashboardRoot.subtleColor
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 30
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !dashboardRoot.wifiEnabled ? "Wi-Fi is Off" : "No Networks Found"
                        color: dashboardRoot.subtleColor
                        font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Item { Layout.fillHeight: true }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                    model: dashboardRoot.wifiEnabled ? wifiModel : null
                    visible: dashboardRoot.wifiEnabled && wifiModel.count > 0

                    delegate: Rectangle {
                        width: ListView.view.width; height: 44; radius: 12
                        color: inUse ? Qt.rgba(0.2, 0.5, 1.0, 0.2) : Qt.rgba(1, 1, 1, 0.05)

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (inUse) {
                                    dashboardRoot.targetWifiSsid = ssid;
                                    dashboardRoot.currentSubView = "wifi-detail";
                                    return;
                                }

                                dashboardRoot.targetWifiSsid = ssid;
                                dashboardRoot.wifiConnectionState = "connecting";
                                dashboardRoot.currentSubView = "wifi-password";
                                wifiQuickConnectProc.ssidName = ssid;
                                wifiQuickConnectProc.running = true;
                            }
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text { text: dashboardRoot.wifiGlyph; opacity: dashboardRoot.wifiSignalOpacity(signal); color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                            Text { text: ssid; color: inUse ? "#3b82f6" : dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: inUse ? Font.Bold : Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: "\u{f033e}"; color: dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; visible: secured && !inUse }
                            Text { text: inUse ? "\uf00c" : "\u{f0142}"; color: inUse ? "#3b82f6" : dashboardRoot.subtleColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: inUse ? 14 : 12 }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // WI-FI NETWORK DETAIL SUB-VIEW (connected network)
        // ------------------------------------------------------------
        Rectangle {
            id: wifiDetailView
            width: parent.width; height: parent.height; color: "transparent"

            readonly property bool isActive: dashboardRoot.currentSubView === "wifi-detail"
            readonly property int myDepth: 2

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center

            transform: Rotation {
                origin.x: wifiDetailView.width / 2; origin.y: wifiDetailView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: wifiDetailView.isActive ? 0 : (wifiDetailView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "wifi" }
                    }
                    Text { text: "Network Info"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    spacing: 6
                    Text { Layout.alignment: Qt.AlignHCenter; text: "\u{f1eb}"; color: "#3b82f6"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 34 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: dashboardRoot.targetWifiSsid; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Connected"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 12 }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "Disconnect"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Medium }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiDisconnectProc.ssidName = dashboardRoot.targetWifiSsid;
                            wifiDisconnectProc.running = true;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                    color: Qt.rgba(0.94, 0.27, 0.27, 0.15)
                    Text { anchors.centerIn: parent; text: "Forget This Network"; color: "#ef4444"; font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Medium }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiForgetProc.ssidName = dashboardRoot.targetWifiSsid;
                            wifiForgetProc.running = true;
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

            readonly property bool isActive: dashboardRoot.currentSubView === "wifi-password"
            readonly property int myDepth: 2

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center
            focus: visible && dashboardRoot.wifiConnectionState === "password"

            transform: Rotation {
                origin.x: wifiFlowView.width / 2; origin.y: wifiFlowView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: wifiFlowView.isActive ? 0 : (wifiFlowView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

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

            readonly property bool isActive: dashboardRoot.currentSubView === "bt"
            readonly property int myDepth: 1

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center

            transform: Rotation {
                origin.x: btView.width / 2; origin.y: btView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: btView.isActive ? 0 : (btView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "main" }
                    }
                    Text { text: "Bluetooth"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }

                    // "Now Discovering" indicator — same visual language
                    // as the Wi-Fi scanning spinner, mirroring macOS/iOS'
                    // Bluetooth settings screen.
                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "transparent"
                        border.color: dashboardRoot.subtleColor; border.width: 2
                        visible: BluetoothService.discovering
                        RotationAnimator on rotation {
                            running: BluetoothService.discovering
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }
                }

                // Empty / off states
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.alignment: Qt.AlignCenter
                    visible: !BluetoothService.available
                        || !BluetoothService.powered
                        || (BluetoothService.connectedDevices.length === 0
                            && BluetoothService.myDevices.length === 0
                            && BluetoothService.otherDevices.length === 0)
                    spacing: 6

                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u{f00af}"
                        opacity: (BluetoothService.available && BluetoothService.powered) ? 0.35 : 1
                        color: dashboardRoot.subtleColor
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 30
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!BluetoothService.available) return "Bluetooth Unavailable"
                            if (!BluetoothService.powered) return "Bluetooth is Off"
                            return "No Devices Found"
                        }
                        color: dashboardRoot.subtleColor
                        font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Item { Layout.fillHeight: true }
                }

                // Device sections
                Flickable {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: sectionColumn.implicitHeight
                    visible: BluetoothService.available && BluetoothService.powered
                        && (BluetoothService.connectedDevices.length > 0
                            || BluetoothService.myDevices.length > 0
                            || BluetoothService.otherDevices.length > 0)

                    ColumnLayout {
                        id: sectionColumn
                        width: parent.width
                        spacing: 14

                        // ---- CONNECTED --------------------------------
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: BluetoothService.connectedDevices.length > 0
                            Text { text: "CONNECTED"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 10; font.weight: Font.Bold; Layout.leftMargin: 4 }
                            Repeater {
                                model: BluetoothService.connectedDevices
                                delegate: BluetoothDeviceRow {
                                    Layout.fillWidth: true
                                    device: modelData
                                    textColor: dashboardRoot.textColor
                                    subtleColor: dashboardRoot.subtleColor
                                    accentColor: dashboardRoot.activeColor
                                    onOpenDetail: {
                                        dashboardRoot.selectedBtDevice = modelData
                                        dashboardRoot.currentSubView = "bt-detail"
                                    }
                                }
                            }
                        }

                        // ---- MY DEVICES --------------------------------
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: BluetoothService.myDevices.length > 0
                            Text { text: "MY DEVICES"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 10; font.weight: Font.Bold; Layout.leftMargin: 4 }
                            Repeater {
                                model: BluetoothService.myDevices
                                delegate: BluetoothDeviceRow {
                                    Layout.fillWidth: true
                                    device: modelData
                                    textColor: dashboardRoot.textColor
                                    subtleColor: dashboardRoot.subtleColor
                                    accentColor: dashboardRoot.activeColor
                                    onOpenDetail: {
                                        dashboardRoot.selectedBtDevice = modelData
                                        dashboardRoot.currentSubView = "bt-detail"
                                    }
                                }
                            }
                        }

                        // ---- OTHER DEVICES ------------------------------
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: BluetoothService.otherDevices.length > 0
                            Text { text: "OTHER DEVICES"; color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 10; font.weight: Font.Bold; Layout.leftMargin: 4 }
                            Repeater {
                                model: BluetoothService.otherDevices
                                delegate: BluetoothDeviceRow {
                                    Layout.fillWidth: true
                                    device: modelData
                                    textColor: dashboardRoot.textColor
                                    subtleColor: dashboardRoot.subtleColor
                                    accentColor: dashboardRoot.activeColor
                                    onOpenDetail: {
                                        dashboardRoot.selectedBtDevice = modelData
                                        dashboardRoot.currentSubView = "bt-detail"
                                    }
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 4 }
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // BLUETOOTH DEVICE DETAIL SUB-VIEW
        // ------------------------------------------------------------
        Rectangle {
            id: btDetailView
            width: parent.width; height: parent.height; color: "transparent"

            readonly property bool isActive: dashboardRoot.currentSubView === "bt-detail"
            readonly property int myDepth: 2

            opacity: isActive ? 1.0 : 0.0
            scale: isActive ? 1.0 : (myDepth < dashboardRoot.activeDepth ? 0.88 : 0.5)
            visible: opacity > 0.01
            transformOrigin: Item.Center

            transform: Rotation {
                origin.x: btDetailView.width / 2; origin.y: btDetailView.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: btDetailView.isActive ? 0 : (btDetailView.myDepth < dashboardRoot.activeDepth ? -10 : 14)
                Behavior on angle {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.01 }
            }
            }

            Behavior on opacity {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: 7.0; damping: 0.48; mass: 0.85; epsilon: 0.001 }
            }

            property var device: dashboardRoot.selectedBtDevice

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16
                visible: btDetailView.device !== null

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.1)
                        Text { anchors.centerIn: parent; text: ""; color: dashboardRoot.textColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.horizontalCenterOffset: -2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dashboardRoot.currentSubView = "bt" }
                    }
                    Text { text: "Device Info"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true; Layout.leftMargin: 8 }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: btDetailView.device ? BluetoothService.glyphFor(btDetailView.device) : ""
                        color: (btDetailView.device && btDetailView.device.connected) ? dashboardRoot.activeColor : dashboardRoot.subtleColor
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 34
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: btDetailView.device ? btDetailView.device.name : ""
                        color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 16; font.weight: Font.Bold
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: btDetailView.device ? BluetoothService.statusFor(btDetailView.device) : ""
                        color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 12
                    }
                }

                // Battery level, when the device reports one.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.08)
                    visible: btDetailView.device && btDetailView.device.batteryAvailable
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10
                        Text { text: "\u{f00af}"; color: dashboardRoot.activeColor; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                        Text { text: "Battery"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Text {
                            text: btDetailView.device ? Math.round(btDetailView.device.battery * 100) + "%" : ""
                            color: dashboardRoot.subtleColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.Medium
                        }
                    }
                }

                // Trusted toggle — trusted devices reconnect automatically
                // without a prompt, same meaning as on macOS/iOS.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.08)
                    visible: btDetailView.device && btDetailView.device.paired
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14
                        Text { text: "Trusted"; color: dashboardRoot.textColor; font.family: "sans-serif"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
                            color: (btDetailView.device && btDetailView.device.trusted) ? "#34c759" : Qt.rgba(1, 1, 1, 0.2)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18; height: 18; radius: 9; color: "white"; anchors.verticalCenter: parent.verticalCenter
                                x: (btDetailView.device && btDetailView.device.trusted) ? 18 : 2
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (btDetailView.device)
                                        BluetoothService.setTrusted(btDetailView.device, !btDetailView.device.trusted)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Connect / Disconnect
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                    color: (btDetailView.device && btDetailView.device.connected) ? Qt.rgba(1, 1, 1, 0.08) : "#3b82f6"
                    Text {
                        anchors.centerIn: parent
                        text: (btDetailView.device && btDetailView.device.connected) ? "Disconnect" : "Connect"
                        color: (btDetailView.device && btDetailView.device.connected) ? dashboardRoot.textColor : "white"
                        font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!btDetailView.device) return
                            BluetoothService.toggleDevice(btDetailView.device)
                        }
                    }
                }

                // Forget This Device
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
                    color: Qt.rgba(0.94, 0.27, 0.27, 0.15)
                    visible: btDetailView.device && btDetailView.device.paired
                    Text { anchors.centerIn: parent; text: "Forget This Device"; color: "#ef4444"; font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Medium }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!btDetailView.device) return
                            BluetoothService.forgetDevice(btDetailView.device)
                            dashboardRoot.selectedBtDevice = null
                            dashboardRoot.currentSubView = "bt"
                        }
                    }
                }
            }
        }
    }
}
