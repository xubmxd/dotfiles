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

        // Force Hyprland to instantly route all keyboard input to the island
        WlrLayershell.keyboardFocus: (dashboardComponent.currentSubView === "wifi-password" || islandBackground.islandState === "wallpaper") 
                                     ? WlrKeyboardFocus.Exclusive 
                                     : WlrKeyboardFocus.None

        color: "transparent"

        // ============================================================
        // TIDE-STYLE SURFACE ARCHITECTURE
        // ============================================================

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

        // ============================================================
        // SURFACE HEIGHT MANAGEMENT
        // ============================================================

        readonly property real requestedWindowHeight:
            Math.ceil(islandBackground.y + islandBackground.targetHeight + 12)

        // Instantly expand the Wayland surface when opening to prevent clipping,
        // but smoothly shrink it exactly in sync with the visual animation to 
        // completely eliminate QtWayland snapping artifacts (the "bounce").
        implicitHeight: Math.max(requestedWindowHeight, Math.ceil(islandBackground.y + islandBackground.height + 12))

        // ============================================================
        // PYWAL COLORS
        // ============================================================

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

        // ============================================================
        // MUSIC
        // ============================================================

        CustomComponents.MusicPlayerData {
            id: musicData
        }

        LyricsService {
            id: lyricsService
            musicData: musicData
        }

        // ============================================================
        // ISLAND NAVIGATOR
        // ============================================================

        property var islandOrder: {
            var islands = ["clock","omni"]

            if (musicData.hasTrack)
                islands.push("music")

            if (musicData.hasTrack && (lyricsService.hasLyrics || lyricsService.loading))
                islands.push("lyrics")

            if (NotificationService.notifications.length > 0)
                islands.push("notifications")

            return islands
        }
        property int selectedIslandIndex: 0

        property bool restoreMusicAfterTrackChange: false
        property bool restoreLyricsAfterTrackChange: false

        // ============================================================
        // TRANSIENT NOTIFICATION PILL
        // ============================================================

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

        property string selectedIsland:
            islandOrder.length > 0
            ? islandOrder[selectedIslandIndex]
            : "clock"

        property string restingState: {
            if (selectedIsland === "music" && musicData.hasTrack)
                return "music-compact"

            if (selectedIsland === "lyrics" && musicData.hasTrack && (lyricsService.hasLyrics || lyricsService.loading))
                return "lyrics"

            if (selectedIsland === "notifications") {
                if (NotificationService.latestNotification)
                    return "notification-pill"

                return "idle"
            }

            if (selectedIsland === "omni")
                return "omni"

            return "idle"
        }

        function normalizeIslandIndex(index) {
            const count = islandOrder.length
            if (count <= 0)
                return 0

            return ((index % count) + count) % count
        }

        function showSelectedIsland() {
            if (selectedIsland === "music" && !musicData.hasTrack)
                selectedIslandIndex = 0

            if (selectedIsland === "lyrics" && (!musicData.hasTrack || (!lyricsService.hasLyrics && !lyricsService.loading)))
                selectedIslandIndex = 0

            hoverExpandDelayTimer.stop()
            hoverCollapseDelayTimer.stop()
            osdTimer.stop()
            wsOsdTimer.stop()
            notificationAutoHideTimer.stop()

            islandWindow.hoverExpandedActive = false
            islandBackground.islandState = islandWindow.restingState
        }

        function nextIsland() {
            if (islandOrder.length <= 0)
                return

            let next = normalizeIslandIndex(selectedIslandIndex + 1)

            while (next !== selectedIslandIndex
                   && ((islandOrder[next] === "music" && !musicData.hasTrack)
                       || (islandOrder[next] === "lyrics" && (!musicData.hasTrack || (!lyricsService.hasLyrics && !lyricsService.loading))))) {
                next = normalizeIslandIndex(next + 1)
            }

            selectedIslandIndex = next
            showSelectedIsland()
        }

        function previousIsland() {
            if (islandOrder.length <= 0)
                return

            let previous = normalizeIslandIndex(selectedIslandIndex - 1)

            while (previous !== selectedIslandIndex
                   && ((islandOrder[previous] === "music" && !musicData.hasTrack)
                       || (islandOrder[previous] === "lyrics" && (!musicData.hasTrack || (!lyricsService.hasLyrics && !lyricsService.loading))))) {
                previous = normalizeIslandIndex(previous - 1)
            }

            selectedIslandIndex = previous
            showSelectedIsland()
        }

        // ============================================================
        // ANTI-JITTER EVICTION TIMERS
        // ============================================================

        Timer {
            id: musicEvictionTimer
            interval: 150 
            onTriggered: {
                if (musicData.hasTrack) return; 

                const current = islandBackground.islandState

                if (islandWindow.selectedIsland === "lyrics") {
                    islandWindow.restoreLyricsAfterTrackChange = true
                    islandWindow.restoreMusicAfterTrackChange = false
                    islandWindow.selectedIslandIndex = 0
                } else if (islandWindow.selectedIsland === "music") {
                    islandWindow.restoreMusicAfterTrackChange = true
                    islandWindow.restoreLyricsAfterTrackChange = false
                    islandWindow.selectedIslandIndex = 0
                }

                if (current === "idle" || current === "music-compact" || current === "music-expanded" || current === "lyrics") {
                    islandBackground.islandState = islandWindow.restingState
                }
            }
        }

        Timer {
            id: lyricsEvictionTimer
            interval: 150 
            onTriggered: {
                if (lyricsService.hasLyrics || lyricsService.loading) return;

                if (islandWindow.selectedIsland === "lyrics")
                    islandWindow.selectedIslandIndex = 0

                if (islandBackground.islandState === "lyrics")
                    islandBackground.islandState = islandWindow.restingState
            }
        }

        Connections {
            target: NotificationService

            function onNotificationsChanged() {
                if (NotificationService.notifications.length === 0) {

                    const notificationIndex =
                        islandWindow.islandOrder.indexOf("notifications")

                    if (islandWindow.selectedIsland === "notifications") {
                        islandWindow.selectedIslandIndex = 0

                        if (islandBackground.islandState === "notification-pill")
                            islandBackground.islandState = "idle"
                    }
                }
            }
        }

        Connections {
            target: musicData

            function onHasTrackChanged() {
                if (!musicData.hasTrack) {
                    musicEvictionTimer.restart()
                } else {
                    musicEvictionTimer.stop()
                    
                    if (islandWindow.restoreLyricsAfterTrackChange) {
                        Qt.callLater(() => {
                            const lyricsIndex = islandWindow.islandOrder.indexOf("lyrics")
                            if (lyricsIndex >= 0) islandWindow.selectedIslandIndex = lyricsIndex
                        })
                        islandWindow.restoreLyricsAfterTrackChange = false
                    } else if (islandWindow.restoreMusicAfterTrackChange) {
                        const musicIndex = islandWindow.islandOrder.indexOf("music")
                        if (musicIndex >= 0) islandWindow.selectedIslandIndex = musicIndex
                        islandWindow.restoreMusicAfterTrackChange = false
                    }
                    
                    const current = islandBackground.islandState
                    if (current === "idle" || current === "music-compact" || current === "music-expanded" || current === "lyrics") {
                        islandBackground.islandState = islandWindow.restingState
                    }
                }
            }
        }

        Connections {
            target: lyricsService

            function onHasLyricsChanged() { lyricsEvictionTimer.restart() }
            function onLoadingChanged() { lyricsEvictionTimer.restart() }
        }

        // ============================================================
        // NOTIFICATIONS SERVER
        // ============================================================

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

        // ============================================================
        // IPC / KEYBINDS
        // ============================================================

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

                if (islandBackground.islandState === "music-expanded") {
                    islandBackground.islandState = islandWindow.restingState
                } else {
                    islandBackground.islandState = "music-expanded"
                }
            }

            function openMusic(): void {
                if (!musicData.hasTrack) return
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()
                islandWindow.hoverExpandedActive = false
                islandBackground.islandState = "music-expanded"
            }

            function closeMusic(): void {
                if (!musicData.hasTrack) return
                hoverExpandDelayTimer.stop()
                islandWindow.hoverExpandedActive = false
                islandBackground.islandState = islandWindow.restingState
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
            function toggleWallpaper(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()

                islandWindow.hoverExpandedActive = false

                if (islandBackground.islandState === "wallpaper") {
                    islandBackground.islandState = islandWindow.restingState
                } else {
                    islandBackground.islandState = "wallpaper"
                }
            }

            function openWallpaper(): void {
                hoverExpandDelayTimer.stop()
                hoverCollapseDelayTimer.stop()
                islandWindow.hoverExpandedActive = false
                islandBackground.islandState = "wallpaper"
            }

            function closeWallpaper(): void {
                if (islandBackground.islandState === "wallpaper") {
                    islandBackground.islandState = islandWindow.restingState
                }
            }

        }

        // ============================================================
        // AUDIO
        // ============================================================

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

        // ============================================================
        // GLOBAL STATE
        // ============================================================

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

        // ============================================================
        // WORKSPACE OSD
        // ============================================================

        onFocusedWorkspaceChanged: {
            if (suppressWsOsd)
                return

            if (!islandMouseArea.containsMouse) {
                islandBackground.islandState =
                    "workspace-osd"

                wsOsdTimer.restart()
            }
        }

        // ============================================================
        // VOLUME OSD
        // ============================================================

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

        // ============================================================
        // BRIGHTNESS
        // ============================================================

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

        // ============================================================
        // OSD TIMERS
        // ============================================================

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

        // ============================================================
        // HOVER LOGIC
        // ============================================================

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

        // ============================================================
        // DYNAMIC ISLAND
        // ============================================================

        Rectangle {
            id: islandBackground

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property string islandState: "idle"

            // --------------------------------------------------------
            // TARGET WIDTH
            // --------------------------------------------------------

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
                case "lyrics":
                    return lyricsPillItem.compactImplicitWidth
                case "notifications":
                    return 430
                case "notification-pill":
                    return notificationPill.implicitWidth
                case "notification-expanded":
                    return notificationPill.implicitWidth
                case "omni":
                    return omniPillItem.compactImplicitWidth
                case "wallpaper":
                    return wallpaperPickerItem.pickerWidth
                default:
                    return 120
                }
            }

            // --------------------------------------------------------
            // TARGET HEIGHT
            // --------------------------------------------------------

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
                case "lyrics":
                    return 40
                case "notifications":
                    return 500
                case "notification-pill":
                    return notificationPill.implicitHeight
                case "notification-expanded":
                    return notificationPill.implicitHeight
                case "omni":
                    return 40
                case "wallpaper":
                    return wallpaperPickerItem.pickerHeight
                default:
                    return 40
                }
            }

            // --------------------------------------------------------
            // TARGET RADIUS
            // --------------------------------------------------------

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
                case "lyrics":
                    return 20
                case "notifications":
                    return 28
                case "notification-pill":
                    return 38
                case "notification-expanded":
                    return 28
                case "omni":
                    return 20
                case "wallpaper":
                    return 28
                default:
                    return 20
                }
            }

            width: targetWidth
            height: targetHeight
            radius: targetRadius

            color: islandWindow.colors.color0
            opacity: 1.0

            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutQuint
                }
            }

            MouseArea {
                id: islandMouseArea

                anchors.fill: parent
                z: -1

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

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
                        || islandBackground.islandState === "lyrics"
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

                    if (mouse.button === Qt.RightButton) {
                        if (islandBackground.islandState === "wallpaper") {
                            islandBackground.islandState = islandWindow.restingState
                        } else {
                            islandWindow.hoverExpandedActive = false
                            islandBackground.islandState = "wallpaper"
                        }
                        return
                    }

                    if (islandBackground.islandState === "idle") {
                        islandWindow.hoverExpandedActive = false
                        islandBackground.islandState = "hover"
                    } else if (islandBackground.islandState === "hover") {
                        islandBackground.islandState = islandWindow.restingState
                    } else if (islandBackground.islandState === "notification-pill") {
                        islandWindow.expandNotificationPill()
                    } else if (islandBackground.islandState === "lyrics" || islandBackground.islandState === "music-compact") {
                        islandWindow.hoverExpandedActive = false
                        islandBackground.islandState = "music-expanded"
                    } else if (islandBackground.islandState === "music-expanded") {
                        islandBackground.islandState = islandWindow.restingState
                    }
                }

                onCanceled: {
                    horizontalSwipe = false
                    swipeEligible = false
                }
            }

            // ========================================================
            // CONTENT
            // ========================================================

            Item {
                // Instantly snap to target sizes to prevent squishing layout during animation
                width: islandBackground.targetWidth
                height: islandBackground.targetHeight
                anchors.centerIn: parent

                CustomComponents.Clock {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    opacity: islandBackground.islandState === "idle" ? 1 : 0
                    scale: islandBackground.islandState === "idle" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
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
                    scale: islandBackground.islandState === "osd" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
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
                    scale: islandBackground.islandState === "hover" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center
                    
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
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                }

                CustomComponents.Workspaces {
                    anchors.fill: parent
                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    backgroundColor: islandWindow.colors.color0
                    subtleColor: islandWindow.colors.color8
                    opacity: islandBackground.islandState === "workspace-osd" ? 1 : 0
                    scale: islandBackground.islandState === "workspace-osd" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
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
                    scale: (islandBackground.islandState === "notification-pill" || islandBackground.islandState === "notification-expanded") ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                }

                CustomComponents.NotificationCenter {
                    anchors.fill: parent
                    opacity: islandBackground.islandState === "notifications" ? 1 : 0
                    scale: islandBackground.islandState === "notifications" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
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
                    scale: (islandBackground.islandState === "music-compact" || islandBackground.islandState === "music-expanded") ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
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
                        islandBackground.islandState = islandWindow.restingState
                    }
                }

                CustomComponents.LyricsPill {
                    id: lyricsPillItem

                    anchors.fill: parent
                    playerData: musicData
                    lyricsService: lyricsService

                    textColor: islandWindow.colors.color15
                    subtleColor: islandWindow.colors.color8

                    accentColor: islandWindow.colors.color5

                    opacity: islandBackground.islandState === "lyrics" ? 1 : 0
                    scale: islandBackground.islandState === "lyrics" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                }
                CustomComponents.OmniPill {
                    id: omniPillItem
                    anchors.fill: parent
                    
                    // Passing Data
                    playerData: musicData
                    workspaceName: islandWindow.focusedWorkspace ? islandWindow.focusedWorkspace.name : "1"
                    
                    // Colors
                    textColor: islandWindow.colors.color15
                    subtleColor: islandWindow.colors.color8
                    accentColor: islandWindow.colors.color5
                    
                    // Setup time strings (you can bind these to your existing clock logic)
                    timeText: Qt.formatDateTime(new Date(), "hh:mm ap")
                    dateText: Qt.formatDate(new Date(), "MMM d")

                    // Animations
                    opacity: islandBackground.islandState === "omni" ? 1 : 0
                    scale: islandBackground.islandState === "omni" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                }

                CustomComponents.WallpaperPicker {
                    id: wallpaperPickerItem
                    anchors.fill: parent

                    textColor: islandWindow.colors.color15
                    activeColor: islandWindow.colors.color4
                    subtleColor: islandWindow.colors.color8
                    backgroundColor: Qt.rgba(1, 1, 1, 0.05)

                    opacity: islandBackground.islandState === "wallpaper" ? 1 : 0
                    scale: islandBackground.islandState === "wallpaper" ? 1.0 : 0.45
                    visible: opacity > 0.01
                    transformOrigin: Item.Center

                    onRequestClose: {
                        islandBackground.islandState = islandWindow.restingState
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                    }
                }
            }
        }
    }
}
