import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // PUBLIC API (matches the rest of your island components)
    // ============================================================

    property color textColor: "white"
    property color activeColor: "#89b4fa"
    property color subtleColor: "#a0a0a0"
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)

    // Root wallpaper directories. Each root's immediate subfolders
    // (2D, anime, lofi, pixel, rice, ...) become selectable categories.
    property var folders: [
        "~/Pictures/wallpapers"
    ]

    property string currentWallpaper: ""

    signal requestClose()

    // Sizing hint for islandBackground.targetWidth/targetHeight, same
    // pattern as MusicPlayer.compactImplicitWidth / LyricsPill etc.
    readonly property real pickerWidth: 620
    readonly property real pickerHeight: 220

    // "categories" -> pick a subfolder first, "wallpapers" -> pick an image
    property string viewMode: "categories"
    property string selectedCategoryPath: ""
    property string selectedCategoryName: ""

    // Grabs keyboard the moment this pill becomes visible, and always
    // reopens at the category list rather than wherever it was left.
    onVisibleChanged: {
        if (visible) {
            viewMode = "categories"
            searchActive = false
            searchQuery = ""
            forceActiveFocus()
            root.refresh()
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

    function refresh() {
        scanCategoriesProc.running = false
        scanCategoriesProc.running = true
    }

    function openCategory(path, name) {
        selectedCategoryPath = path
        selectedCategoryName = name
        viewMode = "wallpapers"
        searchActive = false
        searchQuery = ""
        scanWallpapersProc.running = false
        scanWallpapersProc.running = true
    }

    function backToCategories() {
        viewMode = "categories"
        searchActive = false
        searchQuery = ""
    }

    // ============================================================
    // HOME DIR (needed to expand "~" for the shell commands)
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

    // ============================================================
    // STEP 1 — CATEGORY SCAN (immediate subfolders of each root,
    // with one sample image per folder for a thumbnail preview)
    // ============================================================

    ListModel {
        id: categoryModel
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
                categoryModel.clear()
                for (const line of lines) {
                    const parts = line.split("|")
                    categoryModel.append({
                        path: parts[0] || "",
                        name: parts[1] || "",
                        sample: parts[2] || ""
                    })
                }
                if (categoryModel.count > 0)
                    categoryCarousel.currentIndex = 0
            }
        }
    }

    // ============================================================
    // STEP 2 — WALLPAPER SCAN (scoped to the selected category)
    // ============================================================

    property var allWallpapers: []
    property string searchQuery: ""
    property bool searchActive: false

    ListModel {
        id: wallpaperModel
    }

    function rebuildWallpaperModel() {
        wallpaperModel.clear()
        const q = searchQuery.toLowerCase()
        for (const path of allWallpapers) {
            if (q.length === 0 || root.fileName(path).toLowerCase().indexOf(q) !== -1)
                wallpaperModel.append({ path: path })
        }
        if (wallpaperModel.count > 0)
            wallpaperCarousel.currentIndex = 0
    }

    onSearchQueryChanged: {
        if (viewMode === "wallpapers")
            rebuildWallpaperModel()
    }

    Process {
        id: scanWallpapersProc

        command: [
            "find", root.selectedCategoryPath,
            "-maxdepth", "2",
            "-type", "f",
            "(",
            "-iname", "*.jpg", "-o",
            "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o",
            "-iname", "*.webp",
            ")"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.allWallpapers = String(text).split("\n").filter(l => l.trim().length > 0)
                root.rebuildWallpaperModel()
            }
        }
    }

    // ============================================================
    // APPLY WALLPAPER (awww — drop-in rename of swww)
    // ============================================================

    Process {
        id: applyProc
        property string targetPath: ""
        command: ["awww", "img", targetPath, "--transition-type", "fade"]

        onExited: {
            root.currentWallpaper = targetPath
        }
    }

    function applyWallpaper(path) {
        applyProc.targetPath = path
        applyProc.running = true
    }

    // ============================================================
    // KEYBOARD NAVIGATION
    // ============================================================

    focus: true

    Keys.onLeftPressed: {
        if (viewMode === "categories")
            categoryCarousel.decrementCurrentIndex()
        else
            wallpaperCarousel.decrementCurrentIndex()
    }

    Keys.onRightPressed: {
        if (viewMode === "categories")
            categoryCarousel.incrementCurrentIndex()
        else
            wallpaperCarousel.incrementCurrentIndex()
    }

    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()

    Keys.onEscapePressed: {
        if (searchActive) {
            searchActive = false
            searchQuery = ""
        } else if (viewMode === "wallpapers") {
            backToCategories()
        } else {
            root.requestClose()
        }
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
    // UI
    // ============================================================

    // Back button, top-left — only in the wallpapers view
    Row {
        visible: viewMode === "wallpapers"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        spacing: 4
        z: 2

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
                font.pixelSize: 12
            }
        }
    }

    // Search toggle, top-right
    Rectangle {
        id: searchButton
        width: 26
        height: 26
        radius: 13
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: Qt.rgba(1, 1, 1, searchActive ? 0.14 : 0.07)
        z: 2

        Text {
            anchors.centerIn: parent
            text: "\u{1F50D}"
            font.pixelSize: 12
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
        anchors.rightMargin: 8
        anchors.verticalCenter: searchButton.verticalCenter
        width: 140
        color: root.textColor
        font.pixelSize: 12
        text: root.searchQuery
        clip: true
        z: 2

        onTextChanged: root.searchQuery = text
        Keys.onEscapePressed: {
            searchActive = false
            searchQuery = ""
            root.forceActiveFocus()
        }
        Keys.onReturnPressed: root.forceActiveFocus()
    }

    // ------------------------------------------------------------
    // Category carousel (step 1)
    // ------------------------------------------------------------
    ListView {
        id: categoryCarousel
        visible: viewMode === "categories"

        anchors.fill: parent
        anchors.topMargin: 36
        anchors.bottomMargin: 10

        orientation: ListView.Horizontal
        model: categoryModel
        clip: false
        spacing: 14

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 90
        preferredHighlightEnd: width / 2 + 90
        highlightMoveDuration: 220

        delegate: Item {
            id: catCardRoot
            width: 130
            height: categoryCarousel.height

            readonly property bool isCurrent: ListView.isCurrentItem

            Column {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: catCardRoot.isCurrent ? 150 : 118
                    height: catCardRoot.isCurrent ? 150 : 118
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 14
                    color: root.backgroundColor
                    border.width: catCardRoot.isCurrent ? 2 : 0
                    border.color: root.activeColor
                    opacity: catCardRoot.isCurrent ? 1.0 : 0.55
                    clip: true

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source: model.sample.length > 0 ? ("file://" + model.sample) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 220
                        sourceSize.height: 220
                        visible: model.sample.length > 0
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: 0.28
                    }

                    Text {
                        anchors.centerIn: parent
                        text: model.name
                        color: root.textColor
                        font.pixelSize: catCardRoot.isCurrent ? 14 : 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            categoryCarousel.currentIndex = index
                            root.openCategory(model.path, model.name)
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Wallpaper carousel (step 2)
    // ------------------------------------------------------------
    ListView {
        id: wallpaperCarousel
        visible: viewMode === "wallpapers"

        anchors.fill: parent
        anchors.topMargin: 36
        anchors.bottomMargin: 10

        orientation: ListView.Horizontal
        model: wallpaperModel
        clip: false
        spacing: 14

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 90
        preferredHighlightEnd: width / 2 + 90
        highlightMoveDuration: 220

        delegate: Item {
            id: cardRoot
            width: 130
            height: wallpaperCarousel.height

            readonly property bool isCurrent: ListView.isCurrentItem

            Column {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: cardRoot.isCurrent ? 150 : 118
                    height: cardRoot.isCurrent ? 150 : 118
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 14
                    color: root.backgroundColor
                    border.width: cardRoot.isCurrent ? 2 : 0
                    border.color: root.activeColor
                    opacity: cardRoot.isCurrent ? 1.0 : 0.55
                    clip: true

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 220
                        sourceSize.height: 220
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wallpaperCarousel.currentIndex = index
                            root.applyWallpaper(model.path)
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.fileName(model.path)
                    color: cardRoot.isCurrent ? root.textColor : root.subtleColor
                    font.pixelSize: cardRoot.isCurrent ? 12 : 10
                    font.weight: cardRoot.isCurrent ? Font.DemiBold : Font.Normal
                    elide: Text.ElideMiddle
                    width: 130
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
