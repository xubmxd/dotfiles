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


        // ============================================================
        // HEADER
        // ============================================================

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

                font.family:
                    "JetBrainsMono Nerd Font"

                font.pixelSize: 18

                font.bold: true
            }


            Text {
                visible:
                    NotificationService.count > 0

                text:
                    "Clear All"

                color: "#ffffff"

                font.family:
                    "JetBrainsMono Nerd Font"

                font.pixelSize: 12


                MouseArea {
                    anchors.fill: parent

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        NotificationService.clearAll()
                    }
                }
            }
        }


        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1

            color:
                Qt.rgba(
                    1,
                    1,
                    1,
                    0.12
                )
        }


        // ============================================================
        // EMPTY STATE
        // ============================================================

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

                    color:
                        "#ffffff"

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

                    color:
                        "#888888"

                    font.family:
                        "JetBrainsMono Nerd Font"

                    font.pixelSize: 12
                }
            }
        }


        // ============================================================
        // NOTIFICATION LIST
        // ============================================================

        Flickable {
            id: notificationList

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible:
                NotificationService.count > 0

            clip: true

            contentWidth:
                width

            contentHeight:
                notificationColumn.height


            Column {
                id: notificationColumn

                width:
                    notificationList.width

                spacing: 10


                Repeater {
                    model:
                        NotificationService.notifications


                    delegate: Rectangle {
                        id: notificationCard

                        required property var modelData

                        width:
                            notificationColumn.width

                        height:
                            Math.max(
                                88,
                                notificationContent.implicitHeight + 28
                            )

                        radius: 14

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.06
                            )

                        border.width: 1

                        border.color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.10
                            )


                        Row {
                            id: notificationContent

                            anchors.fill: parent
                            anchors.margins: 14

                            spacing: 12


                            // ------------------------------------------------
                            // ICON
                            // ------------------------------------------------

                            Rectangle {
                                width: 36
                                height: 36

                                radius: 10

                                color:
                                    Qt.rgba(
                                        1,
                                        1,
                                        1,
                                        0.08
                                    )


                                Text {
                                    anchors.centerIn: parent

                                    text:
                                        "󰂚"

                                    color:
                                        "#ffffff"

                                    font.family:
                                        "JetBrainsMono Nerd Font"

                                    font.pixelSize: 18
                                }
                            }


                            // ------------------------------------------------
                            // TEXT
                            // ------------------------------------------------

                            Column {
                                width:
                                    notificationContent.width
                                    - 36
                                    - dismissButton.width
                                    - 24

                                spacing: 4


                                Text {
                                    width:
                                        parent.width

                                    text:
                                        modelData.appName
                                        && modelData.appName.length > 0
                                        ? modelData.appName
                                        : "Notification"

                                    color:
                                        "#aaaaaa"

                                    font.family:
                                        "JetBrainsMono Nerd Font"

                                    font.pixelSize: 11

                                    font.bold: true

                                    elide:
                                        Text.ElideRight
                                }


                                Text {
                                    width:
                                        parent.width

                                    visible:
                                        modelData.summary
                                        && modelData.summary.length > 0

                                    text:
                                        modelData.summary

                                    color:
                                        "#ffffff"

                                    font.family:
                                        "JetBrainsMono Nerd Font"

                                    font.pixelSize: 14

                                    font.bold: true

                                    wrapMode:
                                        Text.WordWrap

                                    maximumLineCount: 2

                                    elide:
                                        Text.ElideRight
                                }


                                Text {
                                    width:
                                        parent.width

                                    visible:
                                        modelData.body
                                        && modelData.body.length > 0

                                    text:
                                        modelData.body

                                    color:
                                        "#b0b0b0"

                                    font.family:
                                        "JetBrainsMono Nerd Font"

                                    font.pixelSize: 12

                                    wrapMode:
                                        Text.WordWrap

                                    maximumLineCount: 3

                                    elide:
                                        Text.ElideRight
                                }


                                // Fallback for notifications with
                                // neither summary nor body.
                                Text {
                                    width:
                                        parent.width

                                    visible:
                                        (!modelData.summary
                                         || modelData.summary.length === 0)
                                        &&
                                        (!modelData.body
                                         || modelData.body.length === 0)

                                    text:
                                        "New notification"

                                    color:
                                        "#ffffff"

                                    font.family:
                                        "JetBrainsMono Nerd Font"

                                    font.pixelSize: 13

                                    font.bold: true
                                }
                            }


                            // ------------------------------------------------
                            // DISMISS BUTTON
                            // ------------------------------------------------

                            Text {
                                id: dismissButton

                                width: 24
                                height: 24

                                text:
                                    "×"

                                color:
                                    "#999999"

                                font.family:
                                    "JetBrainsMono Nerd Font"

                                font.pixelSize: 20

                                horizontalAlignment:
                                    Text.AlignHCenter

                                verticalAlignment:
                                    Text.AlignVCenter


                                MouseArea {
                                    anchors.fill: parent

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    hoverEnabled: true


                                    onEntered:
                                        parent.color = "#ffffff"


                                    onExited:
                                        parent.color = "#999999"


                                    onClicked: {
                                        console.log(
                                            "[Notifications] X clicked:",
                                            modelData.id
                                        )

                                        NotificationService
                                            .dismissNotification(
                                                modelData
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
            }


            ScrollBar.vertical:
                ScrollBar {}
        }
    }
}
