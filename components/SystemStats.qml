import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

RowLayout {
    id: systemStats
    spacing: 0

    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property int volumeLevel: 0
    property int batteryLevel: 0
    property bool batteryCharging: false

    // CPU tracking
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

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

                if (systemStats.lastCpuTotal > 0) {
                    var totalDiff = total - systemStats.lastCpuTotal
                    var idleDiff = idleTime - systemStats.lastCpuIdle
                    if (totalDiff > 0) {
                        systemStats.cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                }
                systemStats.lastCpuTotal = total
                systemStats.lastCpuIdle = idleTime
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
                systemStats.memUsage = Math.round(100 * used / total)
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
                systemStats.diskUsage = parseInt(percentStr.replace('%', '')) || 0
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
                    systemStats.volumeLevel = Math.round(parseFloat(match[1]) * 100)
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
                systemStats.batteryLevel = parseInt(data.trim()) || 0
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
                systemStats.batteryCharging = (data.trim() === "Charging" || data.trim() === "Full")
            }
        }
        Component.onCompleted: running = true
    }

    // Volume control launcher
    Process {
        id: volumeControlProc
        command: ["pavucontrol"]
    }

    // Update timer
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
        }
    }

    // CPU
    Text {
        text: cpuUsage + "% 󰍛"
        color: Theme.colCpu
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
        Layout.rightMargin: 8
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 8
        color: Theme.colMuted
    }

    // Memory
    Text {
        text: memUsage + "% 󰾆"
        color: Theme.colMem
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
        Layout.rightMargin: 8
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 8
        color: Theme.colMuted
    }

    // Disk
    Text {
        text: diskUsage + "% 󰋊"
        color: Theme.colDisk
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
        Layout.rightMargin: 8
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 8
        color: Theme.colMuted
    }

    // Volume
    Text {
        id: volumeText
        text: volumeLevel === 0 ? "󰖁" :
              volumeLevel < 30 ? " " + volumeLevel + "%" :
              volumeLevel < 70 ? "󰕾 " + volumeLevel + "%" :
              " " + volumeLevel + "%"
        color: Theme.colVol
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
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
        color: Theme.colMuted
    }

    // Battery
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
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
        Layout.rightMargin: 8
    }
}
