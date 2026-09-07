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

    property var appDirs: [
        "/usr/share/applications",
        "/usr/local/share/applications",
        "~/.local/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "~/.local/share/flatpak/exports/share/applications"
    ]

    signal requestClose()

    readonly property real launcherWidth: 860 
    readonly property real launcherHeight: 220 

    property int displayCount: 0

    // ============================================================
    // FAVORITES SYSTEM & REORDERING
    // ============================================================
    
    property var favoriteApps: []

    Process {
        id: loadFavsProc
        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell_favorites.txt"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.favoriteApps = String(text).split("\n").filter(l => l.trim().length > 0)
                root.rebuildResults()
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.favoriteApps = []
                root.rebuildResults()
            }
        }
    }

    Process {
        id: saveFavsProc
        property var favsToSave: []
        command: {
            let baseCmd = ["bash", "-c", "printf '%s\\n' \"$@\" > \"$HOME/.cache/quickshell_favorites.txt\"", "--"]
            for (let i = 0; i < favsToSave.length; i++) {
                baseCmd.push(favsToSave[i])
            }
            return baseCmd
        }
    }

    function toggleFavorite(appName) {
        let currentFavs = root.favoriteApps.slice() 
        let idx = currentFavs.indexOf(appName)
        
        if (idx !== -1) currentFavs.splice(idx, 1) 
        else currentFavs.push(appName)  
        
        root.favoriteApps = currentFavs
        saveFavsProc.favsToSave = root.favoriteApps
        saveFavsProc.running = false
        saveFavsProc.running = true
        root.rebuildResults()
    }

    function moveFavorite(sourceName, targetName) {
        if (sourceName === targetName) return;
        
        let currentFavs = root.favoriteApps.slice();
        let fromIdx = currentFavs.indexOf(sourceName);
        let toIdx = currentFavs.indexOf(targetName);
        
        if (fromIdx !== -1 && toIdx !== -1) {
            currentFavs.splice(fromIdx, 1);
            currentFavs.splice(toIdx, 0, sourceName);
            
            root.favoriteApps = currentFavs;
            saveFavsProc.favsToSave = root.favoriteApps;
            saveFavsProc.running = false;
            saveFavsProc.running = true;
            root.rebuildResults();
        }
    }

    // ============================================================
    // APPLICATION SCANNING
    // ============================================================

    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            resultList.currentIndex = 0
            root.refresh()
            searchField.forceActiveFocus()
        }
    }

    function expandHome(path) {
        if (path.indexOf("~") === 0)
            return path.replace("~", homeDirProc.homeDir || "")
        return path
    }

    function refresh() {
        loadFavsProc.running = false
        loadFavsProc.running = true
        scanProc.running = false
        scanProc.running = true
    }

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

    property var allApps: []

    ListModel {
        id: resultModel
    }

    function rebuildResults() {
        resultModel.clear()
        const q = searchField.text.toLowerCase().trim()

        let favs = []
        let others = []

        for (const app of allApps) {
            if (q.length === 0 || app.name.toLowerCase().indexOf(q) !== -1) {
                let isFav = root.favoriteApps.indexOf(app.name) !== -1
                let appData = { name: app.name, exec: app.exec, icon: app.icon, isFav: isFav }
                
                if (isFav) favs.push(appData)
                else others.push(appData)
            }
        }

        // Keep favorites ordered exactly as they are in the cached file
        favs.sort((a, b) => root.favoriteApps.indexOf(a.name) - root.favoriteApps.indexOf(b.name))

        for (const app of favs) resultModel.append(app)
        for (const app of others) resultModel.append(app)

        resultList.currentIndex = resultModel.count > 0 ? 0 : -1
        displayCount = resultModel.count
    }

    Process {
        id: scanProc
        command: {
            const dirs = root.appDirs.map(d => root.expandHome(d))
            const globs = dirs.map(d => "\"" + d + "\"/*.desktop").join(" ")
            const script =
                "for f in " + globs + "; do " +
                "  [ -f \"$f\" ] || continue; " +
                "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
                "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/%[a-zA-Z]//g'); " +
                "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
                "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
                "  hidden=$(grep -m1 '^Hidden=' \"$f\" | cut -d= -f2-); " +
                "  [ \"$nodisplay\" = \"true\" ] && continue; " +
                "  [ \"$hidden\" = \"true\" ] && continue; " +
                "  [ -z \"$name\" ] && continue; " +
                "  [ -z \"$exec\" ] && continue; " +
                "  echo \"$name|$exec|$icon\"; " +
                "done | sort -u -t'|' -k1,1"
            return ["bash", "-c", script]
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text).split("\n").filter(l => l.trim().length > 0)
                const seen = {}
                const apps = []

                for (const line of lines) {
                    const parts = line.split("|")
                    if (parts.length < 2) continue
                    
                    const name = parts[0].trim()
                    const exec = parts[1].trim()
                    const icon = parts.length > 2 ? parts[2].trim() : ""
                    
                    if (seen[name]) continue
                    seen[name] = true
                    
                    apps.push({ name: name, exec: exec, icon: icon })
                }

                root.allApps = apps
                root.rebuildResults()
            }
        }
    }

    Process {
        id: launchProc
        property string targetExec: ""
        command: ["sh", "-c", "setsid -f " + targetExec + " >/dev/null 2>&1"]
    }

    function launch(execLine) {
        launchProc.targetExec = execLine
        launchProc.running = false
        launchProc.running = true
        root.requestClose()
    }

    function launchCurrent() {
        if (resultList.currentIndex < 0 || resultList.currentIndex >= resultModel.count)
            return
        root.launch(resultModel.get(resultList.currentIndex).exec)
    }

    // ============================================================
    // UI
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // ------------------------------------------------------------
        // PILL SEARCH BAR
        // ------------------------------------------------------------
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 500
            Layout.preferredHeight: 40
            radius: 20 
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.04)

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

                    onTextChanged: root.rebuildResults()

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                            if (resultList.currentIndex >= 0 && resultList.currentIndex < resultModel.count) {
                                root.toggleFavorite(resultModel.get(resultList.currentIndex).name)
                            }
                            event.accepted = true; return
                        }
                        
                        // Infinite Wrap-Around Navigation Math
                        if (resultModel.count > 0) {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { 
                                resultList.currentIndex = (resultList.currentIndex + 1) % resultModel.count
                                event.accepted = true; return 
                            }
                            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { 
                                resultList.currentIndex = (resultList.currentIndex - 1 + resultModel.count) % resultModel.count
                                event.accepted = true; return 
                            }
                        }
                        
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.launchCurrent(); event.accepted = true; return }
                        if (event.key === Qt.Key_Escape) {
                            if (text.length > 0) text = ""
                            else root.requestClose()
                            event.accepted = true
                        }
                    }

                    Text {
                        text: "Search apps... (Drag to reorder favorites)"
                        color: root.subtleColor
                        font.pixelSize: 14
                        visible: searchField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // FAKED INFINITE CAROUSEL LIST
        // ------------------------------------------------------------
        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            orientation: ListView.Horizontal
            model: resultModel
            spacing: 12

            // Disabled default drag-to-scroll to prevent interference with icon reordering
            interactive: false 

            preferredHighlightBegin: width / 2 - 55
            preferredHighlightEnd: width / 2 + 55
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 200

            // Infinite Wrap-Around Scrolling
            WheelHandler {
                onWheel: (event) => {
                    if (resultModel.count > 0) {
                        if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                            resultList.currentIndex = (resultList.currentIndex - 1 + resultModel.count) % resultModel.count
                        } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                            resultList.currentIndex = (resultList.currentIndex + 1) % resultModel.count
                        }
                    }
                }
            }

            delegate: Item {
                id: delegateRoot
                width: 110
                height: resultList.height
                z: dragArea.drag.active ? 100 : 1

                readonly property bool isCurrent: ListView.isCurrentItem

                // Target for Drop Events
                DropArea {
                    anchors.fill: parent
                    keys: ["favApp"]
                    onDropped: (drop) => {
                        if (model.isFav) {
                            root.moveFavorite(drop.source.appName, model.name)
                        }
                    }
                }

                // The Draggable Visual Container
                Item {
                    id: visualItem
                    width: 110
                    height: resultList.height

                    property string appName: model.name

                    Drag.active: dragArea.drag.active
                    Drag.source: visualItem
                    Drag.keys: ["favApp"]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    // Snap-back animation when dropped
                    Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    // Dynamic Spatial Math to mimic PathView Cover Flow!
                    readonly property real itemCenter: delegateRoot.x + delegateRoot.width / 2
                    readonly property real listCenter: resultList.contentX + resultList.width / 2
                    readonly property real dist: Math.abs(itemCenter - listCenter)
                    readonly property real normalizedDist: Math.min(1.0, dist / (resultList.width / 2.5))

                    scale: {
                        if (dragArea.pressed) return 0.95
                        if (isCurrent) return 1.15
                        return 1.0 - (normalizedDist * 0.15)
                    }
                    
                    opacity: {
                        if (dragArea.drag.active) return 0.8
                        if (isCurrent) return 1.0
                        return 1.0 - (normalizedDist * 0.5)
                    }
                    
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                    // ========================================================
                    // Moved to TOP of visualItem so Star button renders ABOVE it
                    // ========================================================
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        // Dynamic Cursor depending on state
                        cursorShape: drag.active ? Qt.ClosedHandCursor : (model.isFav ? Qt.OpenHandCursor : Qt.PointingHandCursor)
                        
                        // Only favorites are draggable!
                        drag.target: model.isFav ? visualItem : null
                        drag.axis: Drag.XAxis
                        
                        onReleased: {
                            if (drag.active) {
                                visualItem.Drag.drop()
                                // Instantly snap back to baseline position if drop fails or completes
                                visualItem.x = 0
                                visualItem.y = 0
                            } else {
                                // Handled as a standard click
                                resultList.currentIndex = index
                                Qt.callLater(() => root.launch(model.exec))
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Item {
                            width: 64
                            height: 64
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 16 
                                color: "transparent"
                                border.width: isCurrent ? 2 : 0
                                border.color: Qt.rgba(255, 255, 255, 0.1)
                                clip: true 

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2 
                                    
                                    source: {
                                        if (!model.icon || model.icon.trim() === "") 
                                            return Quickshell.iconPath("application-x-executable", "")
                                        if (model.icon.startsWith("/")) 
                                            return "file://" + model.icon
                                        return Quickshell.iconPath(model.icon, "application-x-executable")
                                    }
                                    
                                    sourceSize: Qt.size(128, 128)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }

                            Text {
                                text: (index + 1).toString()
                                color: root.textColor
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.leftMargin: -12
                                anchors.topMargin: -8
                                opacity: 0.9
                            }

                            // Interactive Star Toggle (Now correctly clicks!)
                            Text {
                                id: starIcon
                                text: model.isFav ? "★" : "☆"
                                color: model.isFav ? "#eab308" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 18
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: -14
                                anchors.topMargin: -12
                                z: 10
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8 
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onEntered: starIcon.scale = 1.3
                                    onExited: starIcon.scale = 1.0
                                    onClicked: root.toggleFavorite(model.name)
                                }
                            }
                        }

                        Text {
                            width: 100
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: model.name
                            color: isCurrent ? root.textColor : root.subtleColor
                            font.pixelSize: 13
                            font.weight: isCurrent ? Font.DemiBold : Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.displayCount === 0
                text: "No matches found."
                color: root.subtleColor
                font.pixelSize: 14
                font.italic: true
            }
        }
    }
}
