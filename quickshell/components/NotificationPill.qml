import QtQuick

Item {
    id: root

    property var notification: null
    property bool expanded: false

    property color textColor: "white"
    property color activeColor: "#60a5fa"
    property color subtleColor: "#888888"

    // Compact pill sizing boundaries
    readonly property real horizontalPadding: 36
    readonly property real iconWidth: 30
    readonly property real contentSpacing: 12
    readonly property real maxPillWidth: 400
    readonly property real minPillWidth: 180

    function cleanText(value) {
        if (value === undefined || value === null)
            return ""

        return String(value)
            .replace(/<[^>]*>/g, " ")
            .replace(/\s+/g, " ")
            .trim()
    }

    readonly property string appName: notification ? cleanText(notification.appName) : ""
    readonly property string summary: notification ? cleanText(notification.summary) : ""
    readonly property string body: notification ? cleanText(notification.body) : ""

    readonly property string primaryText: summary.length > 0 ? summary : (body.length > 0 ? body : "New notification")
    readonly property bool hasSeparateBody: body.length > 0 && body !== primaryText

    // ============================================================
    // DYNAMIC SIZING CALCULATIONS
    // ============================================================

    // Hidden text elements to measure the compact width dynamically
    Text {
        id: appNameMeasure
        visible: false
        text: root.appName.length > 0 ? root.appName : "Notification"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.bold: true
    }

    Text {
        id: primaryTextMeasure
        visible: false
        text: root.primaryText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.bold: true
    }

    readonly property real compactContentWidth: Math.max(appNameMeasure.implicitWidth, primaryTextMeasure.implicitWidth)

    // Calculate dimensions before animations trigger
    readonly property real compactImplicitWidth: Math.max(minPillWidth, Math.min(maxPillWidth, horizontalPadding + iconWidth + contentSpacing + compactContentWidth))
    readonly property real compactImplicitHeight: 50 

    readonly property real expandedImplicitWidth: 430
    // 44 equals top margin (22) + bottom margin (22)
    readonly property real expandedImplicitHeight: expandedColumn.implicitHeight + 44 

    // Expose these dimensions cleanly to the outer shell
    implicitWidth: expanded ? expandedImplicitWidth : compactImplicitWidth
    implicitHeight: expanded ? expandedImplicitHeight : compactImplicitHeight

    opacity: notification ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }

    // ============================================================
    // COMPACT NOTIFICATION PILL
    // ============================================================

    Row {
        id: compactRow
        
        // Fixed width ensures text doesn't jitter during horizontal expansion
        width: compactImplicitWidth - root.horizontalPadding
        anchors.centerIn: parent
        spacing: root.contentSpacing
        visible: !root.expanded

        Item {
            width: root.iconWidth
            height: root.compactImplicitHeight

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: root.activeColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }
            }
        }

        Column {
            width: parent.width - root.iconWidth - root.contentSpacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.appName.length > 0 ? root.appName : "Notification"
                color: root.subtleColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.primaryText
                color: root.textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }

    // ============================================================
    // EXPANDED NOTIFICATION
    // ============================================================

    Column {
        id: expandedColumn

        // Fixed width ensures accurate height measurement before the island stretches
        width: expandedImplicitWidth - 44
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 22

        spacing: 10
        visible: root.expanded

        Row {
            width: parent.width
            height: 30
            spacing: 10

            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: root.activeColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }
            }

            Text {
                width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                text: root.appName.length > 0 ? root.appName : "Notification"
                color: root.subtleColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
        }

        Text {
            width: parent.width
            text: root.primaryText
            color: root.textColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.hasSeparateBody
            text: root.body
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.78)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
    }
}
