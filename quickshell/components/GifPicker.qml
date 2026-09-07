import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property color textColor: "white"
    property color activeColor: "#89b4fa"
    property color subtleColor: "#a0a0a0"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)

    signal requestClose()

    readonly property real pickerWidth: 800
    readonly property real pickerHeight: 280

    // Deletion State
    property bool deletePromptActive: false
    property string pendingDeletePath: ""

    onVisibleChanged: {
        if (visible) {
            searchActive = false
            searchQuery = ""
            deletePromptActive = false
            forceActiveFocus()
            root.refresh()
        }
    }

    function fileName(path) {
        const parts = path.split("/")
        return parts[parts.length - 1]
    }

    function refresh() {
        scanGifsProc.running = false
        scanGifsProc.running = true
    }

    // ============================================================
    // BACKGROUND PROCESSES
    // ============================================================

    property var allGifs: []
    property string searchQuery: ""
    property bool searchActive: false

    ListModel {
        id: gifModel
    }

    function rebuildGifModel() {
        gifModel.clear()
        const q = searchQuery.toLowerCase()
        for (const path of allGifs) {
            if (q.length === 0 || root.fileName(path).toLowerCase().indexOf(q) !== -1)
                gifModel.append({ path: path })
        }
        if (gifModel.count > 0)
            gifCarousel.currentIndex = 0
    }

    onSearchQueryChanged: {
        rebuildGifModel()
    }

    Process {
        id: scanGifsProc
        command: [
            "sh", "-c",
            "find " + Quickshell.env("HOME") + "/Pictures/gifs -maxdepth 1 -type f -iname '*.gif' | sort"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.allGifs = String(text).split("\n").filter(l => l.trim().length > 0)
                root.rebuildGifModel()
            }
        }
    }

    // Applies the GIF using your existing backend script
    Process {
        id: applyProc
        property string targetPath: ""
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-backend.sh", "apply", targetPath]
    }

    function applyGif(path) {
        applyProc.targetPath = path
        applyProc.running = true
    }

    // Safely deletes the GIF without triggering the PNG reindexer
    Process {
        id: deleteProc
        property string targetPath: ""
        command: ["rm", "-f", targetPath]
        onExited: {
            root.refresh()
        }
    }

    // ============================================================
    // KEYBOARD NAVIGATION
    // ============================================================

    focus: true

    Keys.onPressed: (event) => {
        if (deletePromptActive) {
            if (event.key === Qt.Key_Escape) {
                deletePromptActive = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                deleteProc.targetPath = pendingDeletePath
                deleteProc.running = true
                deletePromptActive = false
                event.accepted = true
            }
            return
        }

        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            if (gifCarousel.currentIndex >= 0 && gifModel.count > 0) {
                pendingDeletePath = gifModel.get(gifCarousel.currentIndex).path
                deletePromptActive = true
                event.accepted = true
            }
            return
        }

        if (event.key === Qt.Key_Left) {
            gifCarousel.decrementCurrentIndex()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            gifCarousel.incrementCurrentIndex()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (gifCarousel.currentIndex >= 0 && gifCarousel.currentIndex < gifModel.count)
                root.applyGif(gifModel.get(gifCarousel.currentIndex).path)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (searchActive) {
                searchActive = false
                searchQuery = ""
            } else {
                root.requestClose()
            }
            event.accepted = true
        }
    }

    // ============================================================
    // UI
    // ============================================================

    // Deletion Prompt Overlay
    Rectangle {
        id: deleteOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.85)
        z: 100
        visible: opacity > 0.01
        opacity: deletePromptActive ? 1.0 : 0.0
        radius: 28 

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "Delete GIF?"
                color: "#ef4444"
                font.pixelSize: 20
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.fileName(pendingDeletePath)
                color: root.textColor
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Press [Enter] to confirm or [Esc] to cancel"
                color: root.subtleColor
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Search toggle
    Rectangle {
        id: searchButton
        width: 32
        height: 32
        radius: 16
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        color: Qt.rgba(1, 1, 1, searchActive ? 0.14 : 0.07)
        z: 20

        Text {
            anchors.centerIn: parent
            text: "\u{1F50D}"
            font.pixelSize: 14
            color: root.textColor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                searchActive = !searchActive
                if (searchActive)
                    searchField.forceActiveFocus()
                else {
                    searchQuery = ""
                    root.forceActiveFocus()
                }
            }
        }
    }

    TextInput {
        id: searchField
        visible: searchActive
        anchors.right: searchButton.left
        anchors.rightMargin: 10
        anchors.verticalCenter: searchButton.verticalCenter
        width: 160
        color: root.textColor
        font.pixelSize: 14
        text: root.searchQuery
        clip: true
        z: 20

        onTextChanged: root.searchQuery = text
        Keys.onEscapePressed: {
            searchActive = false
            searchQuery = ""
            root.forceActiveFocus()
        }
        Keys.onReturnPressed: root.forceActiveFocus()
    }

    // ------------------------------------------------------------
    // Infinite GIF Carousel (Cover Flow)
    // ------------------------------------------------------------
    PathView {
        id: gifCarousel
        
        anchors.fill: parent
        anchors.topMargin: 40
        anchors.bottomMargin: 14

        model: gifModel
        clip: true

        pathItemCount: 5
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightMoveDuration: 400
        dragMargin: width / 2

        path: Path {
            startX: -gifCarousel.width * 0.1
            startY: gifCarousel.height / 2 - 15
            
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }

            PathLine { x: gifCarousel.width * 0.2; y: gifCarousel.height / 2 - 15 }
            PathPercent { value: 0.25 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: gifCarousel.width * 0.5; y: gifCarousel.height / 2 - 15 }
            PathPercent { value: 0.5 }
            PathAttribute { name: "itemZ"; value: 2 }
            PathAttribute { name: "itemScale"; value: 1.15 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }

            PathLine { x: gifCarousel.width * 0.8; y: gifCarousel.height / 2 - 15 }
            PathPercent { value: 0.75 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: gifCarousel.width * 1.1; y: gifCarousel.height / 2 - 15 }
            PathPercent { value: 1.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }
        }

        delegate: Item {
            id: cardRoot
            width: 220
            height: gifCarousel.height

            readonly property bool isCurrent: PathView.isCurrentItem
            
            z: PathView.itemZ !== undefined ? PathView.itemZ : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 1.0
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1.0

            Column {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: innerCard
                    width: 220
                    height: 135
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 14
                    color: root.backgroundColor
                    border.width: isCurrent ? 2 : 0
                    border.color: Qt.rgba(255, 255, 255, 0.1)
                    clip: true
                    
                    scale: mouseArea.pressed && isCurrent ? 0.95 : (isCurrent && mouseArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                    // Uses AnimatedImage to play the GIFs live!
                    AnimatedImage {
                        anchors.fill: parent
                        source: "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 440
                        sourceSize.height: 270
                        playing: true 
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        opacity: isCurrent && mouseArea.containsMouse ? 0.1 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (isCurrent) {
                                root.applyGif(model.path)
                            } else {
                                gifCarousel.currentIndex = index
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.fileName(model.path)
                    color: isCurrent ? root.textColor : root.subtleColor
                    font.pixelSize: 13
                    font.weight: isCurrent ? Font.DemiBold : Font.Normal
                    elide: Text.ElideMiddle
                    width: 190
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
