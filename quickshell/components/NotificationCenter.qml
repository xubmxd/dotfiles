import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../services"

Item {
    id: root

    implicitWidth: 430
    implicitHeight: 500


    ColumnLayout {

        anchors.fill: parent

        anchors.margins: 16

        spacing: 14


        // ====================================================
        // HEADER
        // ====================================================

        RowLayout {

            Layout.fillWidth: true


            Text {

                Layout.fillWidth: true

                text:
                    "Notifications"
                    + (
                        NotificationService.count > 0
                        ? " (" + NotificationService.count + ")"
                        : ""
                    )

                color: "#ffffff"

                font.family: "JetBrainsMono Nerd Font"

                font.pixelSize: 18

                font.bold: true
            }


            Text {

                visible:
                    NotificationService.count > 0

                text: "Clear All"

                color: "#ffffff"

                font.family:
                    "JetBrainsMono Nerd Font"

                font.pixelSize: 12


                MouseArea {

                    anchors.fill: parent

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked:
                        NotificationService.clearAll()
                }
            }
        }


        Rectangle {

            Layout.fillWidth: true

            Layout.preferredHeight: 1

            color: "#333333"
        }


        // ====================================================
        // EMPTY STATE
        // ====================================================

        Item {

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible:
                NotificationService.count === 0


            Column {

                anchors.centerIn: parent

                spacing: 10


                Text {

                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text: "󰂜"

                    color: "#777777"

                    font.family:
                        "JetBrainsMono Nerd Font"

                    font.pixelSize: 40
                }


                Text {

                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        "No notifications"

                    color: "#ffffff"

                    font.family:
                        "JetBrainsMono Nerd Font"

                    font.pixelSize: 16

                    font.bold: true
                }


                Text {

                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        "You're all caught up!"

                    color: "#888888"

                    font.family:
                        "JetBrainsMono Nerd Font"

                    font.pixelSize: 12
                }
            }
        }


        // ====================================================
        // NOTIFICATION LIST
        // ====================================================

        Flickable {

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible:
                NotificationService.count > 0

            clip: true

            contentWidth: width

            contentHeight:
                notificationColumn.height


            Column {

                id: notificationColumn

                width:
                    parent.width

                spacing: 10


                Repeater {

                    model:
                        NotificationService.notifications

                    delegate:
                        NotificationCard {

                            width:
                                notificationColumn.width

                            notification:
                                modelData

                            onDismissRequested:
                                NotificationService
                                    .dismissNotification(
                                        notification
                                    )
                        }
                }
            }


            ScrollBar.vertical:
                ScrollBar {}
        }
    }
}
