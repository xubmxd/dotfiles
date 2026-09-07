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

    property var folders: [
        "~/Pictures/wallpapers"
    ]

    property string currentWallpaper: ""

    signal requestClose()

    readonly property real pickerWidth: 800
    readonly property real pickerHeight: 280

    property string viewMode: "categories"
    property string selectedCategoryPath: ""
    property string selectedCategoryName: ""

    // Deletion State
    property bool deletePromptActive: false
    property string pendingDeletePath: ""

    onVisibleChanged: {
        if (visible) {
            viewMode = "categories"
            searchQuery = ""
            if (searchField) searchField.text = ""
            deletePromptActive = false
            
            reindexAllProc.running = false
            reindexAllProc.running = true
            
            root.refresh()
            if (searchField) searchField.forceActiveFocus()
        }
    }

    function expandHome(path) {
        if (path.indexOf("~") === 0)
            return path.replace("~", homeDirProc.homeDir || "")
        return path
    }

    function fileName(path) {
        const parts = path.split("/")
        return parts[parts.length - 1]
    }

    function displayCategoryName(rawName) {
        switch (rawName.toLowerCase()) {
            case "anime":   return "▷  Anime"
            case "scenic":  return "⌇  Scenic"
            case "2d":      return "◇  2D"
            case "lofi":    return "☾  Lofi"
            case "space":   return "✧  Space"
            case "gaming":  return "󰊗  Gaming"
            case "rice":    return "󰣇  Rice"
            case "cars":    return "󰭮  Cars"
            case "pixel":   return "▦  Pixel"
            case "minimal": return "□  Minimal"
            case "nature":  return "♧  Nature"
            default:        return "󰉋  " + rawName.charAt(0).toUpperCase() + rawName.slice(1)
        }
    }

    function refresh() {
        scanCategoriesProc.running = false
        scanCategoriesProc.running = true
    }

    function openCategory(path, name) {
        selectedCategoryPath = path
        selectedCategoryName = name
        viewMode = "wallpapers"
        searchQuery = ""
        searchField.text = ""
        scanWallpapersProc.running = false
        scanWallpapersProc.running = true
    }

    function backToCategories() {
        viewMode = "categories"
        searchQuery = ""
        searchField.text = ""
        rebuildCategoryModel()
    }

    function activateCurrent() {
        if (viewMode === "categories") {
            if (categoryCarousel.currentIndex < 0 || categoryCarousel.currentIndex >= categoryModel.count)
                return
            const item = categoryModel.get(categoryCarousel.currentIndex)
            root.openCategory(item.path, item.name)
        } else {
            if (wallpaperCarousel.currentIndex < 0 || wallpaperCarousel.currentIndex >= wallpaperModel.count)
                return
            root.applyWallpaper(wallpaperModel.get(wallpaperCarousel.currentIndex).path)
        }
    }

    // ============================================================
    // BACKGROUND PROCESSES & MODELS
    // ============================================================

    Process {
        id: homeDirProc
        property string homeDir: ""
        command: ["sh", "-c", "echo $HOME"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                homeDirProc.homeDir = String(text).trim()
                root.refresh()
            }
        }
    }

    Process {
        id: reindexAllProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-backend.sh", "reindex_all"]
    }

    property var allCategories: []
    property var allWallpapers: []
    property string searchQuery: ""

    ListModel { id: categoryModel }
    ListModel { id: wallpaperModel }

    onSearchQueryChanged: {
        if (viewMode === "categories") rebuildCategoryModel()
        else if (viewMode === "wallpapers") rebuildWallpaperModel()
    }

    function rebuildCategoryModel() {
        categoryModel.clear()
        const q = searchQuery.toLowerCase().trim()
        for (const cat of allCategories) {
            if (q.length === 0 || cat.name.toLowerCase().indexOf(q) !== -1) {
                categoryModel.append(cat)
            }
        }
        if (categoryModel.count > 0) categoryCarousel.currentIndex = 0
    }

    function rebuildWallpaperModel() {
        wallpaperModel.clear()
        const q = searchQuery.toLowerCase().trim()
        for (const path of allWallpapers) {
            if (q.length === 0 || root.fileName(path).toLowerCase().indexOf(q) !== -1) {
                wallpaperModel.append({ path: path })
            }
        }
        if (wallpaperModel.count > 0) wallpaperCarousel.currentIndex = 0
    }

    Process {
        id: scanCategoriesProc

        command: {
            const dirs = root.folders.map(f => root.expandHome(f))
            const quoted = dirs.map(d => "\"" + d + "\"").join(" ")
            const script =
                "for root in " + quoted + "; do " +
                "  [ -d \"$root\" ] || continue; " +
                "  for d in \"$root\"/*/; do " +
                "    [ -d \"$d\" ] || continue; " +
                "    name=$(basename \"$d\"); " +
                "    sample=$(find \"$d\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | head -1); " +
                "    echo \"$d|$name|$sample\"; " +
                "  done; " +
                "done"
            return ["bash", "-c", script]
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text).split("\n").filter(l => l.trim().length > 0)
                const cats = []
                for (const line of lines) {
                    const parts = line.split("|")
                    cats.push({
                        path: parts[0] || "",
                        name: root.displayCategoryName(parts[1] || ""),
                        sample: parts[2] || ""
                    })
                }
                root.allCategories = cats
                root.rebuildCategoryModel()
            }
        }
    }

    Process {
        id: scanWallpapersProc
        command: [
            "find", root.selectedCategoryPath,
            "-maxdepth", "2", "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o", "-iname", "*.webp", ")"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.allWallpapers = String(text).split("\n").filter(l => l.trim().length > 0)
                root.rebuildWallpaperModel()
            }
        }
    }

    Process {
        id: backendProc
        property string targetPath: ""
        property string mode: "apply" // "apply" or "delete"
        
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-backend.sh", mode, targetPath]

        onExited: {
            if (mode === "apply") {
                root.currentWallpaper = targetPath
            } else if (mode === "delete") {
                scanWallpapersProc.running = false
                scanWallpapersProc.running = true
            }
        }
    }

    function applyWallpaper(path) {
        backendProc.mode = "apply"
        backendProc.targetPath = path
        backendProc.running = true
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
                text: "Delete Wallpaper?"
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

    // Top Bar (Back Button)
    Row {
        visible: opacity > 0.01
        opacity: viewMode === "wallpapers" ? 1.0 : 0.0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 22
        spacing: 4
        z: 20

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        MouseArea {
            width: backLabel.implicitWidth + 8
            height: 22
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backToCategories()

            Text {
                id: backLabel
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2039 " + root.selectedCategoryName
                color: root.subtleColor
                font.pixelSize: 14
            }
        }
    }

    // ------------------------------------------------------------
    // PILL SEARCH BAR
    // ------------------------------------------------------------
    Rectangle {
        id: searchBarContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 14
        width: 360
        height: 40
        radius: 20
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.04)
        z: 20

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            Text {
                text: "\u{1F50D}"
                font.pixelSize: 14
                color: root.subtleColor
            }

            TextInput {
                id: searchField
                Layout.fillWidth: true
                color: root.textColor
                font.pixelSize: 14
                font.weight: Font.Medium
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                onTextChanged: root.searchQuery = text

                Keys.onPressed: (event) => {
                    if (deletePromptActive) {
                        if (event.key === Qt.Key_Escape) {
                            deletePromptActive = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            backendProc.mode = "delete"
                            backendProc.targetPath = pendingDeletePath
                            backendProc.running = true
                            deletePromptActive = false
                            event.accepted = true
                        }
                        return
                    }

                    if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        if (viewMode === "wallpapers" && wallpaperCarousel.currentIndex >= 0 && wallpaperModel.count > 0) {
                            pendingDeletePath = wallpaperModel.get(wallpaperCarousel.currentIndex).path
                            deletePromptActive = true
                            event.accepted = true
                        }
                        return
                    }

                    // Unified Navigation Mapping
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        if (viewMode === "categories") categoryCarousel.incrementCurrentIndex()
                        else wallpaperCarousel.incrementCurrentIndex()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        if (viewMode === "categories") categoryCarousel.decrementCurrentIndex()
                        else wallpaperCarousel.decrementCurrentIndex()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateCurrent()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_Escape) {
                        if (text.length > 0) {
                            text = ""
                        } else if (viewMode === "wallpapers") {
                            root.backToCategories()
                        } else {
                            root.requestClose()
                        }
                        event.accepted = true
                    }
                }

                Text {
                    text: root.viewMode === "categories" ? "Search categories..." : "Search wallpapers..."
                    color: root.subtleColor
                    font.pixelSize: 14
                    visible: searchField.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Infinite Category Carousel (Cover Flow)
    // ------------------------------------------------------------
    PathView {
        id: categoryCarousel
        
        visible: opacity > 0.01
        opacity: viewMode === "categories" ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        anchors.fill: parent
        anchors.topMargin: 64 // Pushed down to clear the new search bar
        anchors.bottomMargin: 14

        model: categoryModel
        clip: true

        pathItemCount: 5
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightMoveDuration: 400
        dragMargin: width / 2

        path: Path {
            startX: -categoryCarousel.width * 0.1
            startY: categoryCarousel.height / 2 - 15
            
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }

            PathLine { x: categoryCarousel.width * 0.2; y: categoryCarousel.height / 2 - 15 }
            PathPercent { value: 0.25 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: categoryCarousel.width * 0.5; y: categoryCarousel.height / 2 - 15 }
            PathPercent { value: 0.5 }
            PathAttribute { name: "itemZ"; value: 2 }
            PathAttribute { name: "itemScale"; value: 1.15 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }

            PathLine { x: categoryCarousel.width * 0.8; y: categoryCarousel.height / 2 - 15 }
            PathPercent { value: 0.75 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: categoryCarousel.width * 1.1; y: categoryCarousel.height / 2 - 15 }
            PathPercent { value: 1.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }
        }

        delegate: Item {
            id: catCardRoot
            width: 220  
            height: categoryCarousel.height

            readonly property bool isCurrent: PathView.isCurrentItem
            
            z: PathView.itemZ !== undefined ? PathView.itemZ : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 1.0
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1.0

            Column {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: catInnerCard
                    width: 220
                    height: 135
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 14
                    color: root.backgroundColor
                    border.width: isCurrent ? 2 : 0
                    border.color: Qt.rgba(255, 255, 255, 0.1)
                    clip: true
                    
                    scale: catMouseArea.pressed && isCurrent ? 0.95 : (isCurrent && catMouseArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                    Image {
                        anchors.fill: parent
                        source: model.sample.length > 0 ? ("file://" + model.sample) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 440
                        sourceSize.height: 270
                        visible: model.sample.length > 0
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: isCurrent && catMouseArea.containsMouse ? 0.35 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 2
                        anchors.verticalCenterOffset: 2
                        text: model.name
                        color: "black"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        opacity: 0.9
                    }

                    Text {
                        anchors.centerIn: parent
                        text: model.name
                        color: root.textColor
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: catMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (isCurrent) {
                                root.openCategory(model.path, model.name)
                            } else {
                                categoryCarousel.currentIndex = index
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Infinite Wallpaper Carousel (Cover Flow)
    // ------------------------------------------------------------
    PathView {
        id: wallpaperCarousel
        
        visible: opacity > 0.01
        opacity: viewMode === "wallpapers" ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        anchors.fill: parent
        anchors.topMargin: 64 // Pushed down to clear the new search bar
        anchors.bottomMargin: 14

        model: wallpaperModel
        clip: true

        pathItemCount: 5
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightMoveDuration: 400
        dragMargin: width / 2

        path: Path {
            startX: -wallpaperCarousel.width * 0.1
            startY: wallpaperCarousel.height / 2 - 15
            
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }

            PathLine { x: wallpaperCarousel.width * 0.2; y: wallpaperCarousel.height / 2 - 15 }
            PathPercent { value: 0.25 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: wallpaperCarousel.width * 0.5; y: wallpaperCarousel.height / 2 - 15 }
            PathPercent { value: 0.5 }
            PathAttribute { name: "itemZ"; value: 2 }
            PathAttribute { name: "itemScale"; value: 1.15 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }

            PathLine { x: wallpaperCarousel.width * 0.8; y: wallpaperCarousel.height / 2 - 15 }
            PathPercent { value: 0.75 }
            PathAttribute { name: "itemZ"; value: 1 }
            PathAttribute { name: "itemScale"; value: 0.75 }
            PathAttribute { name: "itemOpacity"; value: 0.6 }

            PathLine { x: wallpaperCarousel.width * 1.1; y: wallpaperCarousel.height / 2 - 15 }
            PathPercent { value: 1.0 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemOpacity"; value: 0.1 }
        }

        delegate: Item {
            id: cardRoot
            width: 220
            height: wallpaperCarousel.height

            readonly property bool isCurrent: PathView.isCurrentItem
            
            z: PathView.itemZ !== undefined ? PathView.itemZ : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 1.0
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1.0

            Column {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: wallInnerCard
                    width: 220
                    height: 135
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 14
                    color: root.backgroundColor
                    border.width: isCurrent ? 2 : 0
                    border.color: Qt.rgba(255, 255, 255, 0.1)
                    clip: true
                    
                    scale: wallMouseArea.pressed && isCurrent ? 0.95 : (isCurrent && wallMouseArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 440
                        sourceSize.height: 270
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        opacity: isCurrent && wallMouseArea.containsMouse ? 0.1 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }

                    MouseArea {
                        id: wallMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (isCurrent) {
                                root.applyWallpaper(model.path)
                            } else {
                                wallpaperCarousel.currentIndex = index
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
