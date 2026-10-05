import QtQuick
import Quickshell
import Quickshell.Widgets

// Pywal-styled replacement for the native SNI `display()` popup.
// The stock Qt platform menu (white box in the screenshot) cannot be
// themed, so we walk the DBusMenu with QsMenuOpener and draw it with
// the island's pywal palette instead.
PopupWindow {
    id: root

    required property var anchorItem
    required property var parentWindow
    property var menuHandle: null
    property bool menuOpen: false

    // Pywal palette (wired from shell.qml via TrayBar -> TrayItem).
    property color bgColor: "#1a1a1a"
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color activeColor: "#3b82f6"
    property color attentionColor: "#ef4444"

    signal requestClose

    anchor.window: parentWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6

    // Only walk the menu while it is on screen: every tray app gets a
    // GetLayout the moment the shell starts otherwise.
    visible: menuOpen && menuHandle !== null

    color: "transparent"

    // Fixed width, content-driven height. The popup must NEVER commit
    // a 0x0 surface: Hyprland kills the client with a Wayland protocol
    // error (which is what took the whole island down). Deriving width
    // from menuColumn.implicitWidth would also bind-loop, since the
    // delegates are width-bound to the column.
    implicitWidth: menuBg.width
    implicitHeight: menuBg.height

    onVisibleChanged: {
        if (!visible)
            requestClose()
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.visible ? root.menuHandle : null
    }

    Rectangle {
        id: menuBg
        width: 220
        height: menuColumn.height + 16
        radius: 12
        color: root.bgColor
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        clip: true

        // Entrance: fade + settle, matches island pills.
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1.0 : 0.95
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
        }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
        }

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            // Empty menu fallback.
            Text {
                visible: menuOpener.children.values.length === 0
                width: parent.width
                text: "No actions"
                color: root.subtleColor
                font.family: "Inter"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: menuOpener.children.values

                delegate: Column {
                    id: entryWrap
                    required property var modelData
                    required property int index
                    width: menuColumn.width
                    spacing: 2

                    property bool expanded: false

                    // Separator row.
                    Rectangle {
                        visible: entryWrap.modelData.isSeparator
                        width: parent.width
                        height: 9
                        color: "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.12)
                        }
                    }

                    // Regular entry row.
                    Rectangle {
                        visible: !entryWrap.modelData.isSeparator
                        width: parent.width
                        height: 32
                        radius: 8
                        color: entryMouse.containsMouse && entryWrap.modelData.enabled
                            ? Qt.alpha(root.activeColor, 0.28)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Check / radio indicator.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entryWrap.modelData.buttonType !== QsMenuButtonType.None
                                text: entryWrap.modelData.checkState === Qt.Checked ? "✓" : "○"
                                color: entryWrap.modelData.enabled ? root.activeColor : root.subtleColor
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            // DBus-provided icon, when present.
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entryWrap.modelData.icon !== ""
                                implicitSize: 16
                                width: 16
                                height: 16
                                source: entryWrap.modelData.icon
                                asynchronous: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                    - (entryWrap.modelData.buttonType !== QsMenuButtonType.None ? 20 : 0)
                                    - (entryWrap.modelData.icon !== "" ? 24 : 0)
                                    - (entryWrap.modelData.hasChildren ? 16 : 0)
                                text: entryWrap.modelData.text || ""
                                color: entryWrap.modelData.enabled ? root.textColor : root.subtleColor
                                font.family: "Inter"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            TideIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                visible: entryWrap.modelData.hasChildren
                                name: entryWrap.expanded ? "chevD" : "chevR"
                                color: root.subtleColor
                            }
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: entryWrap.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (!entryWrap.modelData.enabled)
                                    return
                                if (entryWrap.modelData.hasChildren) {
                                    entryWrap.expanded = !entryWrap.expanded
                                } else {
                                    entryWrap.modelData.triggered()
                                    root.requestClose()
                                }
                            }
                        }
                    }

                    // Inline submenu: avoids a second popup window and
                    // keeps everything inside the pywal surface.
                    Loader {
                        width: parent.width
                        active: entryWrap.expanded && entryWrap.modelData.hasChildren
                        sourceComponent: Column {
                            width: entryWrap.width
                            spacing: 2
                            leftPadding: 12

                            QsMenuOpener {
                                id: subOpener
                                menu: entryWrap.modelData
                            }

                            Repeater {
                                model: subOpener.children.values

                                delegate: Rectangle {
                                    required property var modelData
                                    width: entryWrap.width - 12
                                    height: modelData.isSeparator ? 9 : 30
                                    radius: 8
                                    color: !modelData.isSeparator && subMouse.containsMouse && modelData.enabled
                                        ? Qt.alpha(root.activeColor, 0.28)
                                        : "transparent"

                                    Rectangle {
                                        visible: modelData.isSeparator
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                    }

                                    Text {
                                        visible: !modelData.isSeparator
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        text: modelData.text || ""
                                        color: modelData.enabled ? root.textColor : root.subtleColor
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: subMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!modelData.enabled)
                                                return
                                            // Deeper nesting is rare; trigger
                                            // what we can reach inline.
                                            modelData.triggered()
                                            root.requestClose()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
