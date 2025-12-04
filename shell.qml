//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // Theme colors - Chroma Glow style (matching waybar)
    property color colBg: "#1e1e2e"           // Dark background (Catppuccin Mocha base)
    property color colBgTransparent: "transparent"  // Fully transparent background
    property color colFg: "#cdd6f4"           // Light text
    property color colMuted: "#606060"        // Muted/separator color
    property color colClock: "#fe640b"        // Orange for clock
    property color colCpu: "#7287fd"          // Blue for CPU
    property color colMem: "#40a02b"          // Green for memory
    property color colDisk: "#8b4513"         // Brown for disk
    property color colVol: "#40a02b"          // Green for volume
    property color colNetwork: "#dd7878"      // Pink for network
    property color colBluetooth: "#89b4fa"    // Blue for bluetooth
    property color colSlack: "#611f69"        // Slack purple
    property color colWhatsapp: "#25d366"     // WhatsApp green
    property color colWorkspaceActive: "#D3D3D3"  // Light gray for active workspace
    property color colWorkspaceInactive: "grey"   // Grey for inactive
    property color colWindow: "#cba6f7"       // Mauve for window title
    property color colKernel: "#f38ba8"       // Red/pink for kernel

    // Font
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // System info properties
    property string kernelVersion: "Linux"
    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property int volumeLevel: 0
    property int batteryLevel: 0
    property bool batteryCharging: false
    property string activeWindow: "Window"
    property string currentLayout: "Tile"

    // WiFi properties
    property string wifiSSID: ""
    property int wifiSignal: 0
    property bool wifiConnected: false
    property var wifiNetworks: []
    property bool wifiDropdownOpen: false

    // Bluetooth properties
    property bool btPowered: false
    property bool btConnected: false
    property string btConnectedDevice: ""
    property var btDevices: []
    property bool btDropdownOpen: false

    // Slack properties
    property bool slackRunning: false
    property int slackUnread: 0
    property bool slackDnd: false
    property string slackStatus: "active"  // active, away, dnd
    property bool slackDropdownOpen: false

    // WhatsApp properties
    property bool whatsappRunning: false
    property int whatsappUnread: 0
    property bool whatsappDropdownOpen: false

    // Weather property
    property string weatherText: ""

    // Center date property (updated by timer)
    property string centerDate: Qt.formatDateTime(new Date(), "ddd, MMM d")

    // CPU tracking
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    // Kernel version
    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: SplitParser {
            onRead: data => {
                if (data) kernelVersion = data.trim()
            }
        }
        Component.onCompleted: running = true
    }

    // CPU usage
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var user = parseInt(parts[1]) || 0
                var nice = parseInt(parts[2]) || 0
                var system = parseInt(parts[3]) || 0
                var idle = parseInt(parts[4]) || 0
                var iowait = parseInt(parts[5]) || 0
                var irq = parseInt(parts[6]) || 0
                var softirq = parseInt(parts[7]) || 0

                var total = user + nice + system + idle + iowait + irq + softirq
                var idleTime = idle + iowait

                if (lastCpuTotal > 0) {
                    var totalDiff = total - lastCpuTotal
                    var idleDiff = idleTime - lastCpuIdle
                    if (totalDiff > 0) {
                        cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                }
                lastCpuTotal = total
                lastCpuIdle = idleTime
            }
        }
        Component.onCompleted: running = true
    }

    // Memory usage
    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                memUsage = Math.round(100 * used / total)
            }
        }
        Component.onCompleted: running = true
    }

    // Disk usage
    Process {
        id: diskProc
        command: ["sh", "-c", "df / | tail -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var percentStr = parts[4] || "0%"
                diskUsage = parseInt(percentStr.replace('%', '')) || 0
            }
        }
        Component.onCompleted: running = true
    }

    // Volume level (wpctl for PipeWire)
    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var match = data.match(/Volume:\s*([\d.]+)/)
                if (match) {
                    volumeLevel = Math.round(parseFloat(match[1]) * 100)
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Battery level
    Process {
        id: batteryProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                batteryLevel = parseInt(data.trim()) || 0
            }
        }
        Component.onCompleted: running = true
    }

    // Battery charging status
    Process {
        id: batteryStatusProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                batteryCharging = (data.trim() === "Charging" || data.trim() === "Full")
            }
        }
        Component.onCompleted: running = true
    }

    // Volume control launcher
    Process {
        id: volumeControlProc
        command: ["pavucontrol"]
    }

    // WiFi current connection
    Process {
        id: wifiCurrentProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list | grep '^yes' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) {
                    wifiConnected = false
                    wifiSSID = ""
                    wifiSignal = 0
                    return
                }
                var parts = data.trim().split(':')
                if (parts.length >= 3) {
                    wifiConnected = true
                    wifiSSID = parts[1]
                    wifiSignal = parseInt(parts[2]) || 0
                }
            }
        }
        Component.onCompleted: running = true
    }

    // WiFi network scan
    Process {
        id: wifiScanProc
        property string output: ""
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | grep -v '^:' | sort -t: -k2 -nr | head -15"]
        stdout: SplitParser {
            onRead: data => {
                if (data) wifiScanProc.output += data + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else if (output) {
                var lines = output.trim().split('\n')
                var networks = []
                var seen = {}
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(':')
                    if (parts.length >= 2 && parts[0] && !seen[parts[0]]) {
                        seen[parts[0]] = true
                        networks.push({
                            ssid: parts[0],
                            signal: parseInt(parts[1]) || 0,
                            security: parts[2] || ""
                        })
                    }
                }
                wifiNetworks = networks
            }
        }
    }

    // WiFi connect process
    Process {
        id: wifiConnectProc
        property string targetSSID: ""
        command: ["nmcli", "device", "wifi", "connect", targetSSID]
    }

    // Bluetooth status check
    Process {
        id: btStatusProc
        property string output: ""
        command: ["sh", "-c", "bluetoothctl show | grep -E 'Powered|Name'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) btStatusProc.output += data + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else if (output) {
                btPowered = output.includes("Powered: yes")
            }
        }
        Component.onCompleted: running = true
    }

    // Bluetooth connected device check
    Process {
        id: btConnectedProc
        property string output: ""
        command: ["sh", "-c", "bluetoothctl info 2>/dev/null | grep -E 'Name|Connected' | head -2"]
        stdout: SplitParser {
            onRead: data => {
                if (data) btConnectedProc.output += data + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else {
                if (output.includes("Connected: yes")) {
                    btConnected = true
                    var nameMatch = output.match(/Name:\s*(.+)/)
                    if (nameMatch) {
                        btConnectedDevice = nameMatch[1].trim()
                    }
                } else {
                    btConnected = false
                    btConnectedDevice = ""
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Bluetooth paired devices list
    Process {
        id: btDevicesProc
        property string output: ""
        command: ["sh", "-c", "bluetoothctl devices Paired"]
        stdout: SplitParser {
            onRead: data => {
                if (data) btDevicesProc.output += data + "\n"
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else if (output) {
                var lines = output.trim().split('\n')
                var devices = []
                for (var i = 0; i < lines.length; i++) {
                    var match = lines[i].match(/Device\s+([0-9A-F:]+)\s+(.+)/)
                    if (match) {
                        devices.push({
                            mac: match[1],
                            name: match[2]
                        })
                    }
                }
                btDevices = devices
            }
        }
        Component.onCompleted: running = true
    }

    // Bluetooth connect process
    Process {
        id: btConnectProc
        property string targetMAC: ""
        command: ["bluetoothctl", "connect", targetMAC]
    }

    // Bluetooth disconnect process
    Process {
        id: btDisconnectProc
        command: ["bluetoothctl", "disconnect"]
    }

    // Bluetooth power toggle
    Process {
        id: btPowerProc
        property bool powerOn: true
        command: ["bluetoothctl", "power", powerOn ? "on" : "off"]
    }

    // Slack running check
    Process {
        id: slackRunningProc
        command: ["sh", "-c", "pgrep -x slack >/dev/null && echo 'running' || echo 'stopped'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    slackRunning = data.trim() === "running"
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Slack unread count (from dunst history)
    Process {
        id: slackUnreadProc
        command: ["sh", "-c", "dunstctl history | jq '[.data[][] | select(.appname.data == \"Slack\")] | length'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    slackUnread = parseInt(data.trim()) || 0
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Open/Focus Slack
    Process {
        id: slackOpenProc
        command: ["sh", "-c", "hyprctl dispatch focuswindow class:Slack || slack &"]
    }

    // Launch Slack
    Process {
        id: slackLaunchProc
        command: ["slack"]
    }

    // Clear Slack notifications
    Process {
        id: slackClearNotifProc
        command: ["sh", "-c", "dunstctl history | jq -r '.data[][] | select(.appname.data == \"Slack\") | .id.data' | xargs -I{} dunstctl history-rm {}"]
    }

    // WhatsApp running check
    Process {
        id: whatsappRunningProc
        command: ["sh", "-c", "pgrep -f 'whatsapp|WhatsApp' >/dev/null && echo 'running' || echo 'stopped'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    whatsappRunning = data.trim() === "running"
                }
            }
        }
        Component.onCompleted: running = true
    }

    // WhatsApp unread count (from dunst history)
    Process {
        id: whatsappUnreadProc
        command: ["sh", "-c", "dunstctl history | jq '[.data[][] | select(.appname.data | test(\"whatsapp|WhatsApp\"; \"i\"))] | length'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    whatsappUnread = parseInt(data.trim()) || 0
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Open/Focus WhatsApp
    Process {
        id: whatsappOpenProc
        command: ["sh", "-c", "hyprctl dispatch focuswindow class:whatsapp || hyprctl dispatch focuswindow class:WhatsApp || whatsapp-for-linux &"]
    }

    // Launch WhatsApp
    Process {
        id: whatsappLaunchProc
        command: ["whatsapp-for-linux"]
    }

    // Clear WhatsApp notifications
    Process {
        id: whatsappClearNotifProc
        command: ["sh", "-c", "dunstctl history | jq -r '.data[][] | select(.appname.data | test(\"whatsapp|WhatsApp\"; \"i\")) | .id.data' | xargs -I{} dunstctl history-rm {}"]
    }

    // Weather process
    Process {
        id: weatherProc
        command: ["sh", "-c", "$HOME/.config/hypr/UserScripts/Weather.py 2>/dev/null | jq -r '.text // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    weatherText = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Active window title
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    activeWindow = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Current layout (Hyprland: dwindle/master/floating)
    Process {
        id: layoutProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r 'if .floating then \"Floating\" elif .fullscreen == 1 then \"Fullscreen\" else \"Tiled\" end'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    currentLayout = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Slow timer for system stats
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
            diskProc.running = true
            volProc.running = true
            batteryProc.running = true
            batteryStatusProc.running = true
            wifiCurrentProc.running = true
            btStatusProc.running = true
            btConnectedProc.running = true
            slackRunningProc.running = true
            slackUnreadProc.running = true
            whatsappRunningProc.running = true
            whatsappUnreadProc.running = true
        }
    }

    // Weather timer (hourly updates)
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: {
            weatherProc.running = true
        }
    }

    // Event-based updates for window/layout (instant)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            windowProc.running = true
            layoutProc.running = true
        }
    }

    // Backup timer for window/layout (catches edge cases)
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            windowProc.running = true
            layoutProc.running = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 34
            color: "transparent"

            margins {
                top: 3
                bottom: 0
                left: 8
                right: 8
            }

            Rectangle {
                anchors.fill: parent
                color: root.colBgTransparent
                radius: 10

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item { width: 8 }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: "file:///home/jima/.config/quickshell/icons/tonybtw.png"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Item { width: 8 }

                    Repeater {
                        model: 9

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: parent.height
                            color: "transparent"
                            radius: 9

                            property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                            property bool hasWindows: workspace !== null

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                color: parent.isActive ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                                radius: 6
                            }

                            Text {
                                text: index + 1
                                color: parent.isActive ? root.colWorkspaceActive : (parent.hasWindows ? root.colWorkspaceActive : root.colWorkspaceInactive)
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + (index + 1))
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: currentLayout === "Floating" ? "󰉈 " + currentLayout :
                              currentLayout === "Fullscreen" ? "󰊓 " + currentLayout :
                              "󰕰 " + currentLayout
                        color: root.colFg
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 2
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: activeWindow
                        color: root.colWindow
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.maximumWidth: 200
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Left spacer
                    Item { Layout.fillWidth: true }

                    // Center: Date and Weather
                    Text {
                        id: centerDateWeather
                        text: centerDate + (weatherText ? "  |  " + weatherText : "")
                        color: root.colFg
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true

                        Timer {
                            interval: 60000
                            running: true
                            repeat: true
                            onTriggered: centerDate = Qt.formatDateTime(new Date(), "ddd, MMM d")
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                weatherText = ""
                                weatherProc.running = true
                            }
                        }
                    }

                    // Right spacer
                    Item { Layout.fillWidth: true }

                    // Slack indicator
                    Item {
                        id: slackItem
                        Layout.preferredWidth: slackText.width + (slackUnread > 0 ? 16 : 0)
                        Layout.preferredHeight: parent.height
                        Layout.rightMargin: 8

                        Text {
                            id: slackText
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: slackUnread > 0 ? -8 : 0
                            text: "󰒱"
                            color: slackRunning ? root.colFg : root.colMuted
                            font.pixelSize: root.fontSize + 4
                            font.family: root.fontFamily
                            font.bold: true
                        }

                        // Unread badge
                        Rectangle {
                            visible: slackUnread > 0
                            width: 14
                            height: 14
                            radius: 7
                            color: "#e01e5a"
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 6

                            Text {
                                anchors.centerIn: parent
                                text: slackUnread > 9 ? "+" : slackUnread
                                color: "white"
                                font.pixelSize: 9
                                font.family: root.fontFamily
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                slackDropdownOpen = !slackDropdownOpen
                            }
                        }
                    }

                    // WhatsApp indicator
                    Item {
                        id: whatsappItem
                        Layout.preferredWidth: whatsappText.width + (whatsappUnread > 0 ? 16 : 0)
                        Layout.preferredHeight: parent.height
                        Layout.rightMargin: 8

                        Text {
                            id: whatsappText
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: whatsappUnread > 0 ? -8 : 0
                            text: "󰖣"
                            color: whatsappRunning ? root.colWhatsapp : root.colMuted
                            font.pixelSize: root.fontSize + 4
                            font.family: root.fontFamily
                            font.bold: true
                        }

                        // Unread badge
                        Rectangle {
                            visible: whatsappUnread > 0
                            width: 14
                            height: 14
                            radius: 7
                            color: root.colWhatsapp
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 6

                            Text {
                                anchors.centerIn: parent
                                text: whatsappUnread > 9 ? "+" : whatsappUnread
                                color: "white"
                                font.pixelSize: 9
                                font.family: root.fontFamily
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                whatsappDropdownOpen = !whatsappDropdownOpen
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: cpuUsage + "% 󰍛"
                        color: root.colCpu
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: memUsage + "% 󰾆"
                        color: root.colMem
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: diskUsage + "% 󰋊"
                        color: root.colDisk
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        id: volumeText
                        text: volumeLevel === 0 ? "󰖁" :
                              volumeLevel < 30 ? " " + volumeLevel + "%" :
                              volumeLevel < 70 ? "󰕾 " + volumeLevel + "%" :
                              " " + volumeLevel + "%"
                        color: root.colVol
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: volumeControlProc.running = true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        text: batteryCharging ? " " + batteryLevel + "%" :
                              batteryLevel <= 10 ? "󰂎 " + batteryLevel + "%" :
                              batteryLevel <= 20 ? "󰁺 " + batteryLevel + "%" :
                              batteryLevel <= 30 ? "󰁻 " + batteryLevel + "%" :
                              batteryLevel <= 40 ? "󰁼 " + batteryLevel + "%" :
                              batteryLevel <= 50 ? "󰁽 " + batteryLevel + "%" :
                              batteryLevel <= 60 ? "󰁾 " + batteryLevel + "%" :
                              batteryLevel <= 70 ? "󰁿 " + batteryLevel + "%" :
                              batteryLevel <= 80 ? "󰂀 " + batteryLevel + "%" :
                              batteryLevel <= 90 ? "󰂁 " + batteryLevel + "%" :
                              batteryLevel < 100 ? "󰂂 " + batteryLevel + "%" :
                              "󰁹 " + batteryLevel + "%"
                        color: batteryLevel <= 15 ? "#f53c3c" : "#32CD32"
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    // WiFi indicator
                    Item {
                        id: wifiItem
                        Layout.preferredWidth: wifiText.width
                        Layout.preferredHeight: parent.height
                        Layout.rightMargin: 8

                        Text {
                            id: wifiText
                            anchors.centerIn: parent
                            text: !wifiConnected ? "󰤭" :
                                  wifiSignal >= 80 ? "󰤨" :
                                  wifiSignal >= 60 ? "󰤥" :
                                  wifiSignal >= 40 ? "󰤢" :
                                  wifiSignal >= 20 ? "󰤟" : "󰤯"
                            color: wifiConnected ? root.colNetwork : root.colMuted
                            font.pixelSize: root.fontSize + 4
                            font.family: root.fontFamily
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiDropdownOpen = !wifiDropdownOpen
                                if (wifiDropdownOpen) {
                                    wifiScanProc.running = true
                                }
                            }
                        }
                    }

                    // Bluetooth indicator
                    Item {
                        id: btItem
                        Layout.preferredWidth: btText.width
                        Layout.preferredHeight: parent.height
                        Layout.rightMargin: 8

                        Text {
                            id: btText
                            anchors.centerIn: parent
                            text: !btPowered ? "󰂲" :
                                  btConnected ? "󰂱" : "󰂯"
                            color: btPowered ? (btConnected ? root.colBluetooth : root.colBluetooth) : root.colMuted
                            font.pixelSize: root.fontSize + 4
                            font.family: root.fontFamily
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                btDropdownOpen = !btDropdownOpen
                                if (btDropdownOpen) {
                                    btDevicesProc.running = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.colMuted
                    }

                    Text {
                        id: clockText
                        text: " " + Qt.formatDateTime(new Date(), "hh:mm AP")
                        color: root.colClock
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockText.text = " " + Qt.formatDateTime(new Date(), "hh:mm AP")
                        }
                    }

                    Item { width: 8 }
                }
            }

            // WiFi dropdown popup
            PopupWindow {
                id: wifiPopup
                visible: wifiDropdownOpen
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 250
                anchor.rect.y: 40
                implicitWidth: 240
                implicitHeight: Math.min(wifiNetworks.length * 40 + 50, 350)
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    radius: 10
                    border.color: root.colMuted
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header
                        Text {
                            text: wifiConnected ? "󰤨 " + wifiSSID : "󰤭 Not Connected"
                            color: root.colFg
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            font.bold: true
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colMuted
                        }

                        // Network list
                        ListView {
                            id: networkListView
                            width: parent.width
                            height: parent.height - 40
                            clip: true
                            model: wifiNetworks
                            spacing: 2

                            delegate: Rectangle {
                                width: networkListView.width
                                height: 36
                                color: mouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                                radius: 6

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Text {
                                        text: modelData.signal >= 80 ? "󰤨" :
                                              modelData.signal >= 60 ? "󰤥" :
                                              modelData.signal >= 40 ? "󰤢" :
                                              modelData.signal >= 20 ? "󰤟" : "󰤯"
                                        color: root.colNetwork
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: modelData.ssid === wifiSSID ? root.colNetwork : root.colFg
                                        font.pixelSize: root.fontSize - 1
                                        font.family: root.fontFamily
                                        font.bold: modelData.ssid === wifiSSID
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.security ? "󰌾" : ""
                                        color: root.colMuted
                                        font.pixelSize: root.fontSize - 2
                                        font.family: root.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiConnectProc.targetSSID = modelData.ssid
                                        wifiConnectProc.running = true
                                        wifiDropdownOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (!visible) {
                        wifiDropdownOpen = false
                    }
                }
            }

            // Bluetooth dropdown popup
            PopupWindow {
                id: btPopup
                visible: btDropdownOpen
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 280
                anchor.rect.y: 40
                implicitWidth: 240
                implicitHeight: Math.max(btDevices.length * 40 + 100, 150)
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    radius: 10
                    border.color: root.colMuted
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header with power toggle
                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: btPowered ? (btConnected ? "󰂱 " + btConnectedDevice : "󰂯 Bluetooth") : "󰂲 Bluetooth Off"
                                color: root.colFg
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 10
                                color: btPowered ? root.colBluetooth : root.colMuted

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: root.colFg
                                    x: btPowered ? parent.width - width - 2 : 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on x {
                                        NumberAnimation { duration: 150 }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        btPowerProc.powerOn = !btPowered
                                        btPowerProc.running = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colMuted
                        }

                        // Paired devices header
                        Text {
                            text: "Paired Devices"
                            color: root.colMuted
                            font.pixelSize: root.fontSize - 2
                            font.family: root.fontFamily
                            visible: btPowered
                        }

                        // Device list
                        ListView {
                            id: btDeviceListView
                            width: parent.width
                            height: parent.height - 80
                            clip: true
                            model: btDevices
                            spacing: 2
                            visible: btPowered

                            delegate: Rectangle {
                                width: btDeviceListView.width
                                height: 36
                                color: btMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                                radius: 6

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Text {
                                        text: "󰂯"
                                        color: root.colBluetooth
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                    }

                                    Text {
                                        text: modelData.name
                                        color: modelData.name === btConnectedDevice ? root.colBluetooth : root.colFg
                                        font.pixelSize: root.fontSize - 1
                                        font.family: root.fontFamily
                                        font.bold: modelData.name === btConnectedDevice
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.name === btConnectedDevice ? "Connected" : ""
                                        color: root.colBluetooth
                                        font.pixelSize: root.fontSize - 3
                                        font.family: root.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: btMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.name === btConnectedDevice) {
                                            btDisconnectProc.running = true
                                        } else {
                                            btConnectProc.targetMAC = modelData.mac
                                            btConnectProc.running = true
                                        }
                                        btDropdownOpen = false
                                    }
                                }
                            }
                        }

                        // Empty state
                        Text {
                            text: btPowered ? "No paired devices" : "Turn on Bluetooth to see devices"
                            color: root.colMuted
                            font.pixelSize: root.fontSize - 2
                            font.family: root.fontFamily
                            visible: btDevices.length === 0
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                onVisibleChanged: {
                    if (!visible) {
                        btDropdownOpen = false
                    }
                }
            }

            // Slack dropdown popup
            PopupWindow {
                id: slackPopup
                visible: slackDropdownOpen
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 310
                anchor.rect.y: 40
                implicitWidth: 220
                implicitHeight: 180
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    radius: 10
                    border.color: root.colMuted
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header
                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "󰒱 Slack"
                                color: root.colFg
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: slackRunning ? "#2eb67d" : root.colMuted
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colMuted
                        }

                        // Status info
                        Text {
                            text: slackRunning ? (slackUnread > 0 ? slackUnread + " unread notification" + (slackUnread > 1 ? "s" : "") : "No new notifications") : "Slack is not running"
                            color: root.colMuted
                            font.pixelSize: root.fontSize - 2
                            font.family: root.fontFamily
                            width: parent.width
                        }

                        Item { height: 4; width: 1 }

                        // Action buttons
                        Rectangle {
                            width: parent.width
                            height: 36
                            color: openSlackMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: slackRunning ? "󰈈" : "󰐊"
                                    color: root.colSlack
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                }

                                Text {
                                    text: slackRunning ? "Focus Slack" : "Launch Slack"
                                    color: root.colFg
                                    font.pixelSize: root.fontSize - 1
                                    font.family: root.fontFamily
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: openSlackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (slackRunning) {
                                        slackOpenProc.running = true
                                    } else {
                                        slackLaunchProc.running = true
                                    }
                                    slackDropdownOpen = false
                                }
                            }
                        }

                        // Clear notifications button
                        Rectangle {
                            width: parent.width
                            height: 36
                            color: clearNotifMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            radius: 6
                            visible: slackUnread > 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: "󰎟"
                                    color: "#e01e5a"
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                }

                                Text {
                                    text: "Clear notifications"
                                    color: root.colFg
                                    font.pixelSize: root.fontSize - 1
                                    font.family: root.fontFamily
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: clearNotifMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    slackClearNotifProc.running = true
                                    slackUnread = 0
                                    slackDropdownOpen = false
                                }
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (!visible) {
                        slackDropdownOpen = false
                    }
                }
            }

            // WhatsApp dropdown popup
            PopupWindow {
                id: whatsappPopup
                visible: whatsappDropdownOpen
                anchor.window: barWindow
                anchor.rect.x: barWindow.width - 340
                anchor.rect.y: 40
                implicitWidth: 220
                implicitHeight: 180
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    radius: 10
                    border.color: root.colMuted
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Header
                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "󰖣 WhatsApp"
                                color: root.colFg
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: whatsappRunning ? root.colWhatsapp : root.colMuted
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.colMuted
                        }

                        // Status info
                        Text {
                            text: whatsappRunning ? (whatsappUnread > 0 ? whatsappUnread + " unread notification" + (whatsappUnread > 1 ? "s" : "") : "No new notifications") : "WhatsApp is not running"
                            color: root.colMuted
                            font.pixelSize: root.fontSize - 2
                            font.family: root.fontFamily
                            width: parent.width
                        }

                        Item { height: 4; width: 1 }

                        // Action buttons
                        Rectangle {
                            width: parent.width
                            height: 36
                            color: openWhatsappMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            radius: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: whatsappRunning ? "󰈈" : "󰐊"
                                    color: root.colWhatsapp
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                }

                                Text {
                                    text: whatsappRunning ? "Focus WhatsApp" : "Launch WhatsApp"
                                    color: root.colFg
                                    font.pixelSize: root.fontSize - 1
                                    font.family: root.fontFamily
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: openWhatsappMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (whatsappRunning) {
                                        whatsappOpenProc.running = true
                                    } else {
                                        whatsappLaunchProc.running = true
                                    }
                                    whatsappDropdownOpen = false
                                }
                            }
                        }

                        // Clear notifications button
                        Rectangle {
                            width: parent.width
                            height: 36
                            color: clearWhatsappNotifMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            radius: 6
                            visible: whatsappUnread > 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: "󰎟"
                                    color: root.colWhatsapp
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                }

                                Text {
                                    text: "Clear notifications"
                                    color: root.colFg
                                    font.pixelSize: root.fontSize - 1
                                    font.family: root.fontFamily
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: clearWhatsappNotifMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    whatsappClearNotifProc.running = true
                                    whatsappUnread = 0
                                    whatsappDropdownOpen = false
                                }
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (!visible) {
                        whatsappDropdownOpen = false
                    }
                }
            }
        }
    }
}

