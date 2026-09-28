import QtQuick
import Quickshell.Services.SystemTray

// Left-side system tray: one floating bubble per StatusNotifierItem,
// pinned to the Dynamic Island's left edge. Driven reactively by
// SystemTray.items; independent of the island state machine and only
// follows islandBackground geometry from shell.qml.
Item {
    id: trayBar

    property int bubbleSize: 32
    property int itemSpacing: 8
    property color bgColor: "#1a1a1a"
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color activeColor: "#3b82f6"
    property color attentionColor: "#ef4444"

    // Tray applications to hide, matched against SystemTrayItem.id.
    // Add more ids here to hide additional apps, e.g. ["nm-applet", "blueman"].
    property var hiddenIds: ["nm-applet"]

    // Reactive filtered view of the native tray items. Re-evaluates
    // whenever SystemTray.items.values changes or hiddenIds is edited.
    readonly property var visibleItems: SystemTray.items.values.filter(function(item) {
        return item && hiddenIds.indexOf(item.id) < 0
    })

    // Children report tooltip visibility through trayContainer so the
    // PanelWindow can reserve vertical space for the tooltip popup.
    property int tooltipCount: 0
    property var panelWindow: null
    readonly property bool anyTooltipVisible: tooltipCount > 0
    readonly property bool hasItems: visibleItems.length > 0

    width: trayRow.implicitWidth
    height: bubbleSize
    opacity: hasItems ? 1 : 0

    Behavior on width {
        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    Row {
        id: trayRow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Right-to-left so the first tray item sits closest to the
        // island and additional items extend farther left.
        layoutDirection: Qt.RightToLeft
        spacing: trayBar.itemSpacing

        Repeater {
            model: trayBar.visibleItems

            delegate: TrayItem {
                trayItem: modelData
                trayContainer: trayBar
                panelWindow: trayBar.panelWindow
                bubbleSize: trayBar.bubbleSize
                bgColor: trayBar.bgColor
                textColor: trayBar.textColor
                subtleColor: trayBar.subtleColor
                activeColor: trayBar.activeColor
                attentionColor: trayBar.attentionColor
            }
        }
    }
}
