import QtQuick
import QtQuick.Layouts

// Shared todo checkbox row (single-line, elided): 13px box, check,
// strikethrough label. Used by the note editor and the upcoming
// sidecar — one place to change the look.
RowLayout {
    id: root

    property bool checked: false
    property string todoText: ""
    property color textColor: "#ffffff"
    property color subtleColor: "#888888"
    property color accentColor: "#a855f7"

    signal toggled()

    spacing: 6

    Rectangle {
        Layout.preferredWidth: 13
        Layout.preferredHeight: 13
        Layout.alignment: Qt.AlignVCenter
        radius: 3
        color: root.checked ? root.accentColor : "transparent"
        border.color: root.checked ? root.accentColor : root.subtleColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "white"
            font.pixelSize: 9
            font.weight: Font.Bold
            visible: root.checked
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.todoText
        color: root.checked ? root.subtleColor : root.textColor
        font.family: "Inter"
        font.pixelSize: 11
        elide: Text.ElideRight
        maximumLineCount: 1
        font.strikeout: root.checked
    }
}
