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

    readonly property real launcherWidth: 380 
    // Increased height to accommodate the taller, more premium rows
    readonly property real launcherHeight: 360 

    // Taller rows to fit the new iOS-styled app tiles
    readonly property int rowHeight: 44 

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

        for (const app of allApps) {
            if (q.length === 0 || app.name.toLowerCase().indexOf(q) !== -1)
                resultModel.append({ name: app.name, exec: app.exec, icon: app.icon })
        }

        resultList.currentIndex = resultModel.count > 0 ? 0 : -1
    }

    Process {
        id: scanProc

        // Upgraded script to extract the "Icon=" line from the .desktop files
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
                    // Split the 3 parameters we piped out: Name | Exec | Icon
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
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: root.backgroundColor
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "\u{1F50D}"
                    font.pixelSize: 13
                    color: root.activeColor
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

                    Keys.onDownPressed: resultList.incrementCurrentIndex()
                    Keys.onUpPressed: resultList.decrementCurrentIndex()
                    Keys.onReturnPressed: root.launchCurrent()
                    Keys.onEnterPressed: root.launchCurrent()
                    Keys.onEscapePressed: {
                        if (text.length > 0)
                            text = ""
                        else
                            root.requestClose()
                    }

                    Text {
                        text: "Search apps…"
                        color: root.subtleColor
                        font.pixelSize: 14
                        font.italic: true
                        visible: searchField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: resultModel.count
                    color: root.subtleColor
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: resultModel
            spacing: 4

            // Smooth animated highlight "bubble"
            highlight: Rectangle {
                width: resultList.width
                height: root.rowHeight
                radius: 8
                color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.15)
                
                Behavior on y {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                }
            }
            highlightFollowsCurrentItem: true
            highlightMoveDuration: -1 

            delegate: Item {
                id: delegateRoot
                width: resultList.width
                height: root.rowHeight

                readonly property bool isCurrent: ListView.isCurrentItem

                scale: mouseArea.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    // --------------------------------------------------------
                    // iOS Styled Icon Tile
                    // --------------------------------------------------------
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 7 // Classic 22.5% iOS squircle corner ratio
                        color: Qt.rgba(1, 1, 1, 0.04) // Subtle glassy backdrop
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        clip: true 

                        Image {
                            anchors.fill: parent
                            
                            // 4px padding so irregular native Linux SVGs breathe inside the squircle mask
                            anchors.margins: 4 
                            
                            // Let Quickshell securely resolve the icon
                            source: {
                                if (!model.icon || model.icon.trim() === "") 
                                    return Quickshell.iconPath("application-x-executable", "")
                                    
                                if (model.icon.startsWith("/")) 
                                    return "file://" + model.icon
                                    
                                return Quickshell.iconPath(model.icon, "application-x-executable")
                            }
                            
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: model.name
                        color: isCurrent ? root.textColor : root.subtleColor
                        font.pixelSize: 14
                        font.weight: isCurrent ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        resultList.currentIndex = index
                        Qt.callLater(() => root.launch(model.exec))
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: resultModel.count === 0
                text: "No matches found."
                color: root.subtleColor
                font.pixelSize: 14
                font.italic: true
            }
        }
    }
}
