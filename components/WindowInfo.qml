import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import ".."

RowLayout {
    id: windowInfo
    spacing: 0

    property string activeWindow: "Window"
    property string currentLayout: "Tiled"

    // Active window title
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    windowInfo.activeWindow = data.trim()
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
                    windowInfo.currentLayout = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
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

    Text {
        text: currentLayout === "Floating" ? "󰉈 " + currentLayout :
              currentLayout === "Fullscreen" ? "󰊓 " + currentLayout :
              "󰕰 " + currentLayout
        color: Theme.colFg
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
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
        color: Theme.colMuted
    }

    Text {
        text: activeWindow
        color: Theme.colWindow
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
        font.bold: true
        Layout.leftMargin: 8
        Layout.maximumWidth: 200
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
