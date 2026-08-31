import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var notification

    signal dismissRequested(var notification)

    width: parent ? parent.width : 400
    height: contentLayout.implicitHeight + 28

    radius: 16

    color: "#1a1a1a"

    border.width: 1
    border.color: "#333333"


    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: 14

        spacing: 8


        // ====================================================
        // HEADER
        // ====================================================

        RowLayout {

            Layout.fillWidth: true

            spacing: 10


            // App icon placeholder.
            Rectangle {

                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                radius: 8

                color: "#2a2a2a"


                Text {

                    anchors.centerIn: parent

                    text: "󰂚"

                    font.family: "JetBrainsMono Nerd Font"

                    font.pixelSize: 16

                    color: "white"
                }
            }


            Text {

                Layout.fillWidth: true

                text:
                    root.notification.appName
                    || "Application"

                color: "#ffffff"

                font.family: "JetBrainsMono Nerd Font"

                font.pixelSize: 13

                font.bold: true

                elide: Text.ElideRight
            }


            Text {

                text: "󰅖"

                color: "#aaaaaa"

                font.family: "JetBrainsMono Nerd Font"

                font.pixelSize: 16


                MouseArea {

                    anchors.fill: parent

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked:
                        root.dismissRequested(
                            root.notification
                        )
                }
            }
        }


        // ====================================================
        // TITLE
        // ====================================================

        Text {

            Layout.fillWidth: true

            visible:
                root.notification.summary !== ""

            text:
                root.notification.summary

            color: "#ffffff"

            font.family: "JetBrainsMono Nerd Font"

            font.pixelSize: 14

            font.bold: true

            wrapMode: Text.WordWrap
        }


        // ====================================================
        // BODY
        // ====================================================

        Text {

            Layout.fillWidth: true

            visible:
                root.notification.body !== ""

            text:
                root.notification.body

            color: "#b8b8b8"

            font.family: "JetBrainsMono Nerd Font"

            font.pixelSize: 12

            wrapMode: Text.WordWrap

            maximumLineCount: 3

            elide: Text.ElideRight
        }
    }


    Behavior on opacity {

        NumberAnimation {
            duration: 150
        }
    }
}
