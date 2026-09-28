import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// One floating circular bubble for a single StatusNotifierItem.
// Visual language mirrors the timerBubble in shell.qml:
// 32px circle, pywal color0 fill, subtle border, OutQuint entrance.
Item {
    id: trayRoot

    property var trayItem: null
    property var trayContainer: null
    property var panelWindow: null
    property int bubbleSize: 32
    property color bgColor: "#1a1a1a"
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color activeColor: "#3b82f6"
    property color attentionColor: "#ef4444"
    property bool menuOpen: false

    width: bubbleSize
    height: bubbleSize

    readonly property bool needsAttention: trayItem !== null && trayItem.status === Status.NeedsAttention

    readonly property string tipTitle: {
        if (!trayItem)
            return ""
        return trayItem.tooltipTitle || trayItem.title || trayItem.id || ""
    }
    readonly property string tipDesc: trayItem ? (trayItem.tooltipDescription || "") : ""
    readonly property bool hasTip: tipTitle !== "" || tipDesc !== ""

    // Dominant chromatic color of the app icon, used for the bubble
    // border. The rendered icon is grabbed to a temp PNG and quantized
    // (ColorQuantizer cannot read icon-theme provider URLs directly).
    // Colorful icons yield their dominant color; monochrome icons yield
    // a soft ring in their own gray tone; dark/missing icons keep the
    // neutral hairline.
    ColorQuantizer {
        id: iconQuantizer
        depth: 2
        rescaleSize: 32
    }

    readonly property color iconAccent: {
        var fallback = Qt.rgba(1, 1, 1, 0.08)
        var cs = iconQuantizer.colors

        if (!cs || cs.length === 0)
            return fallback

        var bestChroma = fallback
        var bestChromaScore = -1
        var bestMono = fallback
        var bestMonoVal = -1

        for (var i = 0; i < cs.length; i++) {
            var c = cs[i]

            if (c.a < 0.5)
                continue

            if (c.hsvSaturation >= 0.25 && c.hsvValue >= 0.15) {
                var score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3

                if (score > bestChromaScore) {
                    bestChromaScore = score
                    bestChroma = c
                }
            } else if (c.hsvValue >= 0.3 && c.hsvValue > bestMonoVal) {
                bestMonoVal = c.hsvValue
                bestMono = c
            }
        }

        if (bestChromaScore >= 0)
            return bestChroma

        if (bestMonoVal >= 0)
            return Qt.rgba(bestMono.r, bestMono.g, bestMono.b, 0.38)

        return fallback
    }

    function accentPath() {
        var raw = (trayRoot.trayItem && trayRoot.trayItem.id) || "item"
        var safe = String(raw).replace(/[^A-Za-z0-9_.-]+/g, "_")
        return "/tmp/qs-tray-accent-" + safe + ".png"
    }

    // Snapshot the rendered icon and feed it to the quantizer. The
    // source reset forces a reload when the path is unchanged.
    function grabAccent() {
        if (!trayIcon.backer || trayIcon.status !== Image.Ready)
            return

        var path = accentPath()

        trayIcon.backer.grabToImage(function(result) {
            if (!result || !result.saveToFile(path))
                return

            iconQuantizer.source = ""
            Qt.callLater(function() {
                iconQuantizer.source = "file://" + path
            })
        })
    }

    property bool tooltipActive: hoverMouse.containsMouse && hasTip

    onTooltipActiveChanged: {
        if (trayContainer)
            trayContainer.tooltipCount += tooltipActive ? 1 : -1
    }

    Component.onDestruction: {
        if (tooltipActive && trayContainer)
            trayContainer.tooltipCount -= 1
    }

    // Entrance: fade + grow.
    opacity: 0
    scale: 0.5
    transformOrigin: Item.Center

    Component.onCompleted: {
        opacity = 1
        scale = 1
        accentGrabber.restart()
    }

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }
    Behavior on scale {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    Rectangle {
        id: bubbleBg

        anchors.fill: parent
        radius: width / 2
        color: trayRoot.bgColor
        border.color: trayRoot.needsAttention ? trayRoot.attentionColor : trayRoot.iconAccent
        // Ring weight matches the timer bubble's progress ring (2.5px);
        // attention gets one extra px on top of its red color + dot.
        border.width: trayRoot.needsAttention ? 3 : 2.5
    }

    // One-shot settle grab: lets the icon paint before snapshotting.
    // Restarts (debounced) on every icon load; never polls. Declared
    // before the icon so early status changes can reach it.
    Timer {
        id: accentGrabber
        interval: 400
        repeat: false
        onTriggered: grabAccent()
    }

    IconImage {
        id: trayIcon

        anchors.centerIn: parent
        implicitSize: 18
        source: trayRoot.trayItem ? trayRoot.trayItem.icon : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Image.Ready)
                accentGrabber.restart()
        }
    }

    // Fallback glyph while the icon is loading or unresolvable.
    Text {
        anchors.centerIn: parent
        visible: trayIcon.status !== Image.Ready
        text: (trayRoot.tipTitle || "?").charAt(0).toUpperCase()
        color: trayRoot.textColor
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: Font.Bold
    }

    // Subtle NeedsAttention marker using the pywal palette.
    Rectangle {
        visible: trayRoot.needsAttention
        width: 8
        height: 8
        radius: 4
        x: parent.width - 9
        y: 1
        color: trayRoot.attentionColor
        border.color: trayRoot.bgColor
        border.width: 1
    }

    // Pywal-styled menu via QsMenuOpener (see TrayMenu.qml). The native
    // SNI display() path draws a stock Qt popup (white box) that cannot
    // be themed, so we toggle our own PopupWindow instead.
    function openMenu() {
        if (!trayRoot.trayItem || !trayRoot.trayItem.hasMenu)
            return

        trayRoot.menuOpen = !trayRoot.menuOpen
    }

    function closeMenu() {
        trayRoot.menuOpen = false
    }

    TrayMenu {
        anchorItem: bubbleBg
        parentWindow: trayRoot.panelWindow
        menuHandle: trayRoot.trayItem ? trayRoot.trayItem.menu : null
        menuOpen: trayRoot.menuOpen && trayRoot.panelWindow !== null
        bgColor: trayRoot.bgColor
        textColor: trayRoot.textColor
        subtleColor: trayRoot.subtleColor
        activeColor: trayRoot.activeColor
        attentionColor: trayRoot.attentionColor
        onRequestClose: trayRoot.closeMenu()
    }

    MouseArea {
        id: hoverMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: function(mouse) {
            if (!trayRoot.trayItem)
                return

            if (mouse.button === Qt.LeftButton) {
                if (trayRoot.trayItem.onlyMenu)
                    trayRoot.openMenu()
                else
                    trayRoot.trayItem.activate()
            } else if (mouse.button === Qt.MiddleButton) {
                trayRoot.trayItem.secondaryActivate()
            } else if (mouse.button === Qt.RightButton) {
                trayRoot.openMenu()
            }
        }

        onWheel: function(wheel) {
            if (!trayRoot.trayItem)
                return

            var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
            var delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y

            if (delta !== 0)
                trayRoot.trayItem.scroll(delta, horizontal)
        }
    }

    // Compact tooltip below the bubble.
    Item {
        id: tipBox

        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter

        width: Math.min(220, Math.max(tipTitleLabel.implicitWidth, tipDescLabel.implicitWidth) + 20)
        height: tipColumn.implicitHeight + 12

        z: 70
        opacity: trayRoot.tooltipActive ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuint }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: trayRoot.bgColor
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
        }

        Column {
            id: tipColumn

            anchors.centerIn: parent
            width: parent.width - 20
            spacing: 2

            Text {
                id: tipTitleLabel

                width: Math.min(tipBox.width - 20, implicitWidth)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: trayRoot.tipTitle
                color: trayRoot.textColor
                font.family: "Inter"
                font.pixelSize: 11
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                id: tipDescLabel

                width: Math.min(tipBox.width - 20, implicitWidth)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: trayRoot.tipDesc
                color: trayRoot.subtleColor
                font.family: "Inter"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
