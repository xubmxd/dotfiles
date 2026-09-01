import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "components" as CustomComponents
import "services"

ShellRoot {
    PanelWindow {
        id: islandWindow

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "custom-island"
        WlrLayershell.exclusiveZone: 40

        focusable: dashboardComponent.currentSubView === "wifi-password"

        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
        }

        margins.top: 5

        mask: Region {
            Region {
                x: Math.round(islandBackground.x)
                y: Math.round(islandBackground.y)
                width: Math.round(islandBackground.width)
                height: Math.round(islandBackground.height)
            }
        }

        readonly property real requestedWindowHeight:
            Math.ceil(islandBackground.y + islandBackground.targetHeight + 12)

        implicitHeight: Math.max(requestedWindowHeight, Math.ceil(islandBackground.y + islandBackground.height + 12))

        FileView {
            id: pywal

            path:
                Quickshell.env("HOME")
                + "/.cache/wal/colors.json"

            blockLoading: true
            watchChanges: true

            onFileChanged:
                reload()
        }

        property var colors: {
            try {
                var parsed = JSON.parse(pywal.text())

                if (parsed.colors)
                    return parsed.colors
            } catch (error) {
                console.warn(
                    "Failed to load pywal colors:",
                    error
                )
            }

            return {
                color0: "#1a1a1a", color1: "#ef4444", color2: "#22c55e", color3: "#eab308",
                color4: "#3b82f6", color5: "#a855f7", color6: "#06b6d4", color7: "#d1d5db",
                color8: "#555555", color9: "#f87171", color10: "#4ade80", color11: "#facc15",
                color12: "#60a5fa", color13: "#c084fc", color14: "#22d3ee", color15: "#ffffff"
            }
        }

        CustomComponents.MusicPlayerData {
            id: musicData
        }

        property var islandOrder: {
            var islands = ["clock"]

            if (musicData.hasTrack)
                islands.push("music")

            if (NotificationService.latestNotification)
                islands.push("notifications")

            return islands
        }

        property int selectedIslandIndex: 0

        property string selectedIsland: {
            if (islandOrder.length === 0)
                return "clock"

            const index = Math.max(
                0,
                Math.min(selectedIslandIndex, islandOrder.length - 1)
            )

            return islandOrder[index]
        }

        property string restingState: {
            switch (selectedIsland) {
            case "music":
                return musicData.hasTrack
                    ? "music-compact"
                    : "idle"

            case "notifications":
                return NotificationService.latestNotification
                    ? "notification-pill"
                    : "idle"

            default:
                return "idle"
            }
        }

        function islandIndex(name) {
            return islandOrder.indexOf(name)
        }

        function selectIsland(name) {
            const index = islandIndex(name)

            if (index >= 0)
                selectedIslandIndex = index
        }

        function selectMusicIsland() {
            if (!musicData.hasTrack)
                return false

            const index = islandIndex("music")

            if (index < 0)
                return false

            selectedIslandIndex = index
            return true
        }

        function selectClockIsland() {
            const index = islandIndex("clock")

            selectedIslandIndex = index >= 0 ? index : 0
        }

        function normalizeIslandIndex(index) {
            const count = islandOrder.length

            if (count <= 0)
                return 0

            return ((index % count) + count) % count
        }

        function showSelectedIsland() {
            if (selectedIslandIndex >= islandOrder.length)
                selectedIslandIndex = 0

            if (selectedIslandIndex < 0)
                selectedIslandIndex = 0

            hoverExpandDelayTimer.stop()
            hoverCollapseDelayTimer.stop()
            osdTimer.stop()
            wsOsdTimer.stop()
            notificationAutoHideTimer.stop()

            hoverExpandedActive = false

            islandBackground.islandState = restingState
        }

        function nextIsland() {
            if (islandOrder.length <= 1) {
                showSelectedIsland()
                return
            }

            selectedIslandIndex =
                normalizeIslandIndex(selectedIslandIndex + 1)

            showSelectedIsland()
        }

        function previousIsland() {
            if (islandOrder.length <= 1) {
                showSelectedIsland()
                return
            }

            selectedIslandIndex =
                normalizeIslandIndex(selectedIslandIndex - 1)

            showSelectedIsland()
        }

        Connections {
            target: musicData

            function onHasTrackChanged() {
                const currentState = islandBackground.islandState

                if (!musicData.hasTrack) {
                    if (islandWindow.selectedIsland === "music")
                        islandWindow.selectClockIsland()

                    if (currentState === "music-compact"
                            || currentState === "music-expanded") {

                        islandBackground.islandState =
                            islandWindow.restingState
                    }

                    return
                }
            }
        }

        Connections {
            target: NotificationService

            function onNotificationsChanged() {
                if (NotificationService.notifications.length === 0) {

                    if (islandWindow.selectedIsland === "notifications") {
                        islandWindow.selectClockIsland()
                    }

                    if (islandBackground.islandState === "notifications"
                            || islandBackground.islandState === "notification-pill"
                            || islandBackground.islandState === "notification-expanded") {

                        islandBackground.islandState =
                            islandWindow.restingState
                    }
                }
            }
        }

        property string notificationReturnState: "idle"

        property bool notificationPillActive:
            islandBackground.islandState === "notification-pill"
            || islandBackground.islandState === "notification-expanded"

        function showNotificationPill(notification) {
            if (!notification)
                return

            const current = islandBackground.islandState

            if (!notificationPillActive) {
                if (current === "idle"
                    || current === "music-compact"
                    || current === "music-expanded"
                    || current === "notifications") {
                    notificationReturnState = current
                } else {
                    notificationReturnState = restingState
                }
            }

            hoverExpandDelayTimer.stop()
            hoverCollapseDelayTimer.stop()
            osdTimer.stop()
            wsOsdTimer.stop()

            hoverExpandedActive = false

            islandBackground.islandState = "notification-pill"
            notificationAutoHideTimer.restart()
        }

        function restoreFromNotification() {
            notificationAutoHideTimer.stop()
            islandBackground.islandState = notificationReturnState
        }

        function expandNotificationPill() {
            if (!NotificationService.latestNotification)
                return

            notificationAutoHideTimer.stop()

            if (!notificationPillActive)
                showNotificationPill(NotificationService.latestNotification)

            islandBackground.islandState = "notification-expanded"
        }

        function dismissNotificationPill() {
            if (notificationPillActive)
                restoreFromNotification()
        }

        NotificationServer {
            id: notificationServer

            bodySupported: true

            onNotification: function(notification) {
                notification.tracked = true
                NotificationService.addNotification(notification)
                islandWindow.showNotificationPill(notification)

                console.log(
                    "[Notifications] Received:",
                    notification.appName,
                    "-",
                    notification.summary
                )
            }
        }

        Timer {
            id: notificationAutoHideTimer

            interval: 5000
            repeat: false

            onTriggered: {
                if (islandBackground.islandState === "notification-pill")
                    islandWindow.restoreFromNotification()
            }
        }

        IpcHandler {
            target: "island"

            function nextIsland(): void {
                islandWindow.nextIsland()
            }

            function previousIsland(): void {
                islandWindow.previousIsland()
            }

            function toggleMusic(): void {
                if (!musicData.hasTrack)
                    return

                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false

                islandWindow.selectMusicIsland()

                if (islandBackground.islandState === "music-expanded") {
                    islandBackground.islandState = "music-compact"
                } else {
                    islandBackground.islandState = "music-expanded"
                }
            }

            function openMusic(): void {
                if (!musicData.hasTrack)
                    return

                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false

                islandWindow.selectMusicIsland()

                islandBackground.islandState = "music-expanded"
            }

            function closeMusic(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false

                if (!musicData.hasTrack) {
                    islandWindow.selectClockIsland()
                    islandBackground.islandState =
                        islandWindow.restingState
                    return
                }

                islandWindow.selectMusicIsland()

                islandBackground.islandState = "music-compact"
            }

            function expandNotification(): void {
                islandWindow.expandNotificationPill()
            }

            function dismissNotification(): void {
                islandWindow.dismissNotificationPill()
            }

            function openNotifications(): void {
                if (!NotificationService.latestNotification
                    && NotificationService.notifications.length === 0)
                    return

                notificationAutoHideTimer.stop()
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false
                islandBackground.islandState = "notifications"
            }

            function closeNotifications(): void {
                if (islandBackground.islandState === "notifications") {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }

            function toggleNotifications(): void {
                if (islandBackground.islandState === "notifications") {
                    closeNotifications()
                } else {
                    openNotifications()
                }
            }

            function clearNotifications(): void {
                NotificationService.clearAll()
                if (islandBackground.islandState === "notifications")
                    islandBackground.islandState =
                        islandWindow.restingState
            }

            function toggleDashboard(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false

                if (islandBackground.islandState === "hover") {
                    islandBackground.islandState =
                        islandWindow.restingState
                } else {
                    islandBackground.islandState = "hover"
                }
            }

            function openDashboard(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()
                islandWindow.hoverExpandedActive = false
                islandBackground.islandState = "hover"
            }

            function closeDashboard(): void {
                if (islandBackground.islandState === "hover") {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }

            function close(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()
                osdTimer.stop()
                wsOsdTimer.stop()
                notificationAutoHideTimer.stop()
                islandWindow.hoverExpandedActive = false
                islandBackground.islandState =
                    islandWindow.restingState
            }
        }

        PwObjectTracker {
            id: audioTracker
            objects: [ Pipewire.defaultAudioSink ]
        }

        property real trackedVolume: {
            var sink = Pipewire.defaultAudioSink

            if (sink && sink.audio && sink.audio.volume !== undefined) {
                return sink.audio.volume
            }

            return 0
        }

        property bool isMuted: {
            var sink = Pipewire.defaultAudioSink

            if (sink && sink.audio && sink.audio.muted !== undefined) {
                return sink.audio.muted
            }

            return false
        }

        property real trackedBrightness: -1
        property real pendingBrightness: -1
        property string currentOsd: "volume"
        property bool suppressOsd: true
        property var focusedWorkspace: Hyprland.focusedWorkspace
        property bool suppressWsOsd: true

        Timer {
            interval: 1000
            running: true

            onTriggered: {
                islandWindow.suppressOsd = false
                islandWindow.suppressWsOsd = false
            }
        }

        onFocusedWorkspaceChanged: {
            if (suppressWsOsd)
                return

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState =
                    "workspace-osd"

                wsOsdTimer.restart()
            }
        }

        onTrackedVolumeChanged: {
            if (suppressOsd)
                return

            currentOsd = "volume"

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        onIsMutedChanged: {
            if (suppressOsd)
                return

            currentOsd = "volume"

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState = "osd"
                osdTimer.restart()
            }
        }

        Process {
            id: brightnessProc

            command: [ "brightnessctl", "-m" ]

            stdout: StdioCollector {
                onStreamFinished: {
                    var raw = String(text).trim()
                    var parts = raw.split(",")

                    if (parts.length < 4)
                        return

                    var brightness =
                        parseInt(parts[3].replace("%", "")) / 100.0

                    if (isNaN(brightness))
                        return

                    if (islandWindow.trackedBrightness === -1) {
                        islandWindow.trackedBrightness = brightness
                    } else if (Math.abs(brightness - islandWindow.trackedBrightness) > 0.01) {

                        islandWindow.trackedBrightness = brightness
                        islandWindow.currentOsd = "brightness"

                        if (!islandWindow.suppressOsd
                            && !islandMouseArea.containsMouse) {

                            islandBackground.islandState = "osd"
                            osdTimer.restart()
                        }
                    }
                }
            }
        }

        Process {
            id: brightnessSetProc
            property real targetValue: 0
            command: ["brightnessctl", "s", Math.round(targetValue * 100) + "%"]
            
            onExited: {
                if (islandWindow.pendingBrightness >= 0) {
                    targetValue = islandWindow.pendingBrightness;
                    islandWindow.pendingBrightness = -1;
                    running = true;
                }
            }
        }

        Timer {
            interval: 200
            running: true
            repeat: true
            onTriggered: {
                if (!brightnessProc.running)
                    brightnessProc.running = true
            }
        }

        Timer {
            id: osdTimer
            interval: 2000
            onTriggered: {
                if (!islandMouseArea.containsMouse) {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }
        }

        Timer {
            id: wsOsdTimer
            interval: 1500
            onTriggered: {
                if (!islandMouseArea.containsMouse) {
                    islandBackground.islandState =
                        islandWindow.restingState
                }
            }
        }

        property bool hoverExpandedActive: false

        Timer {
            id: hoverExpandDelayTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (!islandMouseArea.containsMouse)
                    return

                if (islandBackground.islandState
                    !== "music-compact") {
                    return
                }

                islandWindow.hoverExpandedActive = true

                islandBackground.islandState =
                    "music-expanded"
            }
        }

        Timer {
            id: hoverCollapseDelayTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (islandMouseArea.containsMouse)
                    return

                if (islandWindow.hoverExpandedActive
                    && islandBackground.islandState
                    === "music-expanded") {

                    islandWindow.hoverExpandedActive = false
                    islandBackground.islandState =
                        islandWindow.restingState
                    return
                }

                if (islandBackground.islandState === "osd") {
                    osdTimer.restart()
                    return
                }

                if (islandBackground.islandState === "workspace-osd") {
                    wsOsdTimer.restart()
                }
            }
        }

        Rectangle {
            id: islandBackground

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property string islandState: "idle"

            readonly property real targetWidth: {
                switch (islandState) {
                case "idle":
                    return 120
                case "hover":
                    return 380
                case "osd":
                    return 300
                case "workspace-osd":
                    return 260
                case "music-compact":
                    return musicPlayerItem.compactImplicitWidth
                case "music-expanded":
                    return 380
                case "notifications":
                    return 430
                case "notification-pill":
                    return notificationPill.implicitWidth
                case "notification-expanded":
                    return notificationPill.implicitWidth
                default:
                    return 120
                }
            }

            readonly property real targetHeight: {
                switch (islandState) {
                case "idle":
                    return 40
                case "hover":
                    return 336
                case "osd":
                    return 60
                case "workspace-osd":
                    return 50
                case "music-compact":
                    return 40
                case "music-expanded":
                    return 200
                case "notifications":
                    return 500
                case "notification-pill":
                    return notificationPill.implicitHeight
                case "notification-expanded":
                    return notificationPill.implicitHeight
                default:
                    return 40
                }
            }

            readonly property real targetRadius: {
                switch (islandState) {
                case "idle":
                    return 20
                case "hover":
                    return 24
                case "osd":
                    return 30
                case "workspace-osd":
                    return 25
                case "music-compact":
                    return 20
                case "music-expanded":
                    return 32
                case "notifications":
                    return 28
                case "notification-pill":
                    return 38
                case "notification-expanded":
                    return 28
                default:
                    return 20
                }
            }

            width: targetWidth
            height: targetHeight
            radius: targetRadius

            color: islandWindow.colors.color0
            opacity: 0.85

            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            MouseArea {
                id: islandMouseArea

                anchors.fill: parent
                z: -1

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                property real pressX: 0
                property real pressY: 0
                property bool horizontalSwipe: false
                property bool swipeEligible: false

                readonly property real swipeThreshold: 55
                readonly property real verticalTolerance: 45

                onEntered: {
                    hoverCollapseDelayTimer.stop()

                    if (islandBackground.islandState === "music-compact")
                        hoverExpandDelayTimer.restart()
                }

                onExited: {
                    hoverExpandDelayTimer.stop()
                    hoverCollapseDelayTimer.restart()
                }

                onPressed: function(mouse) {
                    pressX = mouse.x
                    pressY = mouse.y
                    horizontalSwipe = false

                    swipeEligible =
                        islandBackground.islandState === "idle"
                        || islandBackground.islandState === "music-compact"
                        || islandBackground.islandState === "notification-pill"
                }

                onPositionChanged: function(mouse) {
                    if (!swipeEligible || horizontalSwipe)
                        return

                    const dx = mouse.x - pressX
                    const dy = mouse.y - pressY

                    if (Math.abs(dy) > verticalTolerance)
                        return

                    if (Math.abs(dx) > 12 && Math.abs(dx) > Math.abs(dy)) {
                        horizontalSwipe = true
                        hoverExpandDelayTimer.stop()
                        hoverCollapseDelayTimer.stop()
                    }
                }

                onReleased: function(mouse) {
                    if (!swipeEligible || !horizontalSwipe)
                        return

                    const dx = mouse.x - pressX
                    const dy = mouse.y - pressY

                    if (Math.abs(dy) <= verticalTolerance && Math.abs(dx) >= swipeThreshold) {
                        if (dx < 0)
                            islandWindow.nextIsland()
                        else
                            islandWindow.previousIsland()
                    }

                    horizontalSwipe = false
                    swipeEligible = false
                }
                
                onClicked: function(mouse) {
                    if (horizontalSwipe) return

                    if (islandBackground.islandState === "idle") {
                        islandWindow.hoverExpandedActive = false
                        islandBackground.islandState = "hover"
                    } else if (islandBackground.islandState === "hover") {
                        islandBackground.islandState = islandWindow.restingState
                    } else if (islandBackground.islandState === "notification-pill") {
                        islandWindow.expandNotificationPill()
                    }
                }

                onCanceled: {
                    horizontalSwipe = false
                    swipeEligible = false
                }
            }

            Item {
                anchors.fill: parent

                CustomComponents.Clock {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    opacity: islandBackground.islandState === "idle" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                CustomComponents.Osd {
                    anchors.fill: parent
                    activeColor: islandWindow.colors.color4
                    subtleColor: islandWindow.colors.color8
                    backgroundColor: islandWindow.colors.color0
                    osdType: islandWindow.currentOsd
                    osdValue: islandWindow.currentOsd === "volume"
                        ? islandWindow.trackedVolume
                        : (islandWindow.trackedBrightness === -1 ? 0 : islandWindow.trackedBrightness)
                    isMuted: islandWindow.isMuted
                    opacity: islandBackground.islandState === "osd" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                CustomComponents.Dashboard {
                    id: dashboardComponent
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    backgroundColor: islandWindow.colors.color0
                    subtleColor: islandWindow.colors.color8
                    
                    opacity: islandBackground.islandState === "hover" ? 1 : 0
                    visible: opacity > 0
                    
                    onRequestClose: {
                        islandBackground.islandState = islandWindow.restingState;
                    }
                    
                    displayBrightness: islandWindow.trackedBrightness === -1 ? 0 : islandWindow.trackedBrightness
                    onBrightnessChanged: (val) => {
                        islandWindow.trackedBrightness = val; 
                        
                        if (brightnessSetProc.running) {
                            islandWindow.pendingBrightness = val; 
                        } else {
                            brightnessSetProc.targetValue = val;
                            brightnessSetProc.running = true;
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }
                }

                CustomComponents.Workspaces {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    backgroundColor: islandWindow.colors.color0
                    subtleColor: islandWindow.colors.color8
                    opacity: islandBackground.islandState === "workspace-osd" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                CustomComponents.NotificationPill {
                    id: notificationPill

                    anchors.fill: parent
                    notification: NotificationService.latestNotification
                    expanded: islandBackground.islandState === "notification-expanded"

                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    subtleColor: islandWindow.colors.color8

                    opacity: (islandBackground.islandState === "notification-pill"
                              || islandBackground.islandState === "notification-expanded") ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 220 }
                    }
                }

                CustomComponents.NotificationCenter {
                    anchors.fill: parent
                    opacity: islandBackground.islandState === "notifications" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }
                }

                CustomComponents.MusicPlayer {
                    id: musicPlayerItem

                    anchors.fill: parent
                    playerData: musicData
                    isExpanded: islandBackground.islandState === "music-expanded"

                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    
                    accentColor: islandWindow.colors.color5 
                    
                    subtleColor: islandWindow.colors.color8
                    backgroundColor: Qt.rgba(1, 1, 1, 0.05)

                    opacity: (islandBackground.islandState === "music-compact"
                              || islandBackground.islandState === "music-expanded") ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }

                    onRequestExpand: {
                        hoverExpandDelayTimer.stop()
                        hoverCollapseDelayTimer.stop()
                        islandWindow.hoverExpandedActive = false
                        islandBackground.islandState = "music-expanded"
                    }

                    onRequestCompact: {
                        hoverExpandDelayTimer.stop()
                        islandWindow.hoverExpandedActive = false
                        islandBackground.islandState = "music-compact"
                    }
                }
            }
        }
    }
}
