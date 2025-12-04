import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import ".."

RowLayout {
    id: workspaceBar
    spacing: 0

    // Window class to icon mapping (matching waybar)
    property var windowIcons: ({
        // Browsers
        "firefox": " ",
        "org.mozilla.firefox": " ",
        "librewolf": " ",
        "floorp": " ",
        "cachy-browser": " ",
        "zen": "󰰷 ",
        "zen-browser": "󰰷 ",
        "zen-alpha": "󰰷 ",
        "microsoft-edge": " ",
        "chromium": " ",
        "google-chrome": " ",
        "brave-browser": "󰖟 ",
        "vivaldi": " ",

        // Terminals (using nf-md-console_line icon)
        "kitty": "󰞷 ",
        "konsole": "󰞷 ",
        "alacritty": "󰞷 ",
        "com.mitchellh.ghostty": "󰞷 ",
        "ghostty": "󰞷 ",
        "org.wezfurlong.wezterm": "󰞷 ",
        "foot": "󰞷 ",
        "xterm": "󰞷 ",
        "urxvt": "󰞷 ",

        // Communication (using nf-md icons)
        "telegram-desktop": "󰔁 ",
        "org.telegram.desktop": "󰔁 ",
        "discord": "󰙯 ",
        "webcord": "󰙯 ",
        "vesktop": "󰙯 ",
        "slack": "󰒱 ",
        "Slack": "󰒱 ",
        "whatsapp": "󰖣 ",
        "wasistlos": "󰖣 ",
        "zapzap": "󰖣 ",
        "thunderbird": "󰇮 ",

        // Code editors
        "code": "󰨞 ",
        "code-oss": "󰨞 ",
        "vscodium": "󰨞 ",
        "codium": "󰨞 ",
        "dev.zed.zed": "󰵁 ",
        "zed": "󰵁 ",
        "subl": "󰅳 ",
        "sublime_text": "󰅳 ",
        "jetbrains-idea": " ",
        "neovide": " ",

        // Media
        "mpv": " ",
        "vlc": "󰕼 ",
        "spotify": " ",
        "cider": "󰎆 ",
        "celluloid": " ",

        // File managers
        "thunar": "󰝰 ",
        "nemo": "󰝰 ",
        "nautilus": "󰝰 ",
        "dolphin": "󰝰 ",
        "pcmanfm": "󰝰 ",

        // System
        "pavucontrol": "󱡫 ",
        "org.pulseaudio.pavucontrol": "󱡫 ",
        "nwg-look": " ",
        "steam": " ",
        "obs": " ",
        "com.obsproject.studio": " ",
        "gimp": " ",
        "virt-manager": " ",

        // Office
        "libreoffice-writer": " ",
        "libreoffice-calc": " ",
        "libreoffice-startcenter": "󰏆 ",

        // Claude Code / AI
        "claude": "󰚩 ",
    })

    // Store windows per workspace - individual properties for proper QML binding
    property string ws1Icons: ""
    property string ws2Icons: ""
    property string ws3Icons: ""
    property string ws4Icons: ""
    property string ws5Icons: ""
    property string ws6Icons: ""
    property string ws7Icons: ""
    property string ws8Icons: ""
    property string ws9Icons: ""

    function getWsIcons(wsId) {
        switch(wsId) {
            case 1: return ws1Icons
            case 2: return ws2Icons
            case 3: return ws3Icons
            case 4: return ws4Icons
            case 5: return ws5Icons
            case 6: return ws6Icons
            case 7: return ws7Icons
            case 8: return ws8Icons
            case 9: return ws9Icons
            default: return ""
        }
    }

    function getWindowIcon(windowClass) {
        if (!windowClass) return ""
        // Exact match first (case-sensitive)
        if (windowIcons[windowClass]) return windowIcons[windowClass]
        // Lowercase match
        var lowerClass = windowClass.toLowerCase()
        if (windowIcons[lowerClass]) return windowIcons[lowerClass]
        // Partial match (case-insensitive)
        for (var key in windowIcons) {
            var lowerKey = key.toLowerCase()
            if (lowerClass.includes(lowerKey) || lowerKey.includes(lowerClass)) {
                return windowIcons[key]
            }
        }
        return " " // default icon
    }

    // Process to get window list - use jq to simplify parsing
    Process {
        id: windowsProc
        property string output: ""
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[] | select(.workspace.id > 0 and .workspace.id <= 9) | \"\\(.workspace.id):\\(.class)\"'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    windowsProc.output += data.trim() + "\n"
                }
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else {
                var wsIcons = {}
                var lines = output.trim().split('\n')
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(':')
                    if (parts.length >= 2) {
                        var wsId = parseInt(parts[0])
                        var windowClass = parts.slice(1).join(':')  // handle class names with colons
                        if (wsId > 0 && wsId <= 9) {
                            if (!wsIcons[wsId]) wsIcons[wsId] = {icons: [], seen: {}}
                            var icon = workspaceBar.getWindowIcon(windowClass)
                            if (!wsIcons[wsId].seen[icon]) {
                                wsIcons[wsId].seen[icon] = true
                                wsIcons[wsId].icons.push(icon)
                            }
                        }
                    }
                }
                // Set individual properties for proper QML binding
                workspaceBar.ws1Icons = wsIcons[1] ? wsIcons[1].icons.slice(0, 4).join("") : ""
                workspaceBar.ws2Icons = wsIcons[2] ? wsIcons[2].icons.slice(0, 4).join("") : ""
                workspaceBar.ws3Icons = wsIcons[3] ? wsIcons[3].icons.slice(0, 4).join("") : ""
                workspaceBar.ws4Icons = wsIcons[4] ? wsIcons[4].icons.slice(0, 4).join("") : ""
                workspaceBar.ws5Icons = wsIcons[5] ? wsIcons[5].icons.slice(0, 4).join("") : ""
                workspaceBar.ws6Icons = wsIcons[6] ? wsIcons[6].icons.slice(0, 4).join("") : ""
                workspaceBar.ws7Icons = wsIcons[7] ? wsIcons[7].icons.slice(0, 4).join("") : ""
                workspaceBar.ws8Icons = wsIcons[8] ? wsIcons[8].icons.slice(0, 4).join("") : ""
                workspaceBar.ws9Icons = wsIcons[9] ? wsIcons[9].icons.slice(0, 4).join("") : ""
            }
        }
        Component.onCompleted: running = true
    }

    // Update on Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            windowsProc.running = true
        }
    }

    // Backup timer
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: windowsProc.running = true
    }

    // Calculate the highest workspace we need to show
    property int maxWorkspaceWithWindows: {
        var max = 0
        for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
            var ws = Hyprland.workspaces.values[i]
            if (ws.id > max && ws.id <= 9) max = ws.id
        }
        return max
    }

    property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1

    // Show at least 5, or more if there are windows/active workspace beyond 5
    property int workspacesToShow: Math.max(5, maxWorkspaceWithWindows, activeWorkspaceId)

    Repeater {
        model: workspaceBar.workspacesToShow

        Rectangle {
            id: wsRect
            Layout.preferredWidth: Math.max(28, wsContent.implicitWidth + 12)
            Layout.preferredHeight: workspaceBar.height
            color: "transparent"
            radius: 9

            property int wsId: index + 1
            property var workspace: Hyprland.workspaces.values.find(ws => ws.id === wsId) ?? null
            property bool isActive: workspaceBar.activeWorkspaceId === wsId
            property bool hasWindows: workspace !== null
            property string windowIconsStr: wsId === 1 ? workspaceBar.ws1Icons :
                                          wsId === 2 ? workspaceBar.ws2Icons :
                                          wsId === 3 ? workspaceBar.ws3Icons :
                                          wsId === 4 ? workspaceBar.ws4Icons :
                                          wsId === 5 ? workspaceBar.ws5Icons :
                                          wsId === 6 ? workspaceBar.ws6Icons :
                                          wsId === 7 ? workspaceBar.ws7Icons :
                                          wsId === 8 ? workspaceBar.ws8Icons :
                                          wsId === 9 ? workspaceBar.ws9Icons : ""

            // Background highlight for active workspace
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: parent.isActive ? Theme.colWorkspaceActive : "transparent"
                radius: 6
                opacity: parent.isActive ? 0.2 : 0
            }

            // Underline indicator for active workspace
            Rectangle {
                width: parent.width - 8
                height: 2
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 2
                color: Theme.colWorkspaceActive
                visible: parent.isActive
                radius: 1
            }

            Row {
                id: wsContent
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: wsRect.wsId
                    color: wsRect.isActive ? Theme.colWorkspaceActive : (wsRect.hasWindows ? Theme.colWorkspaceActive : Theme.colWorkspaceInactive)
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: wsRect.isActive
                }

                Text {
                    text: wsRect.windowIconsStr
                    color: wsRect.isActive ? Theme.colWorkspaceActive : Theme.colFg
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
                    visible: wsRect.windowIconsStr.length > 0
                    opacity: 0.8
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + wsRect.wsId)
            }
        }
    }
}
