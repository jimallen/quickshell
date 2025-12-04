import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

Item {
    id: slackWidget
    Layout.preferredWidth: slackText.width + (slackUnread > 0 ? 16 : 0)
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 8

    required property var barWindow

    property bool slackRunning: false
    property int slackUnread: 0
    property bool slackDropdownOpen: false

    // Slack running check
    Process {
        id: slackRunningProc
        command: ["sh", "-c", "pgrep -x slack >/dev/null && echo 'running' || echo 'stopped'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    slackWidget.slackRunning = data.trim() === "running"
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
                    slackWidget.slackUnread = parseInt(data.trim()) || 0
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

    // Update timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            slackRunningProc.running = true
            slackUnreadProc.running = true
        }
    }

    Text {
        id: slackText
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: slackUnread > 0 ? -8 : 0
        text: "󰒱"
        color: slackRunning ? Theme.colFg : Theme.colMuted
        font.pixelSize: Theme.fontSize + 4
        font.family: Theme.fontFamily
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
            font.family: Theme.fontFamily
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: slackDropdownOpen = !slackDropdownOpen
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
            color: Theme.colBg
            radius: 10
            border.color: Theme.colMuted
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
                        color: Theme.colFg
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: slackRunning ? "#2eb67d" : Theme.colMuted
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.colMuted
                }

                // Status info
                Text {
                    text: slackRunning ? (slackUnread > 0 ? slackUnread + " unread notification" + (slackUnread > 1 ? "s" : "") : "No new notifications") : "Slack is not running"
                    color: Theme.colMuted
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
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
                            color: Theme.colSlack
                            font.pixelSize: Theme.fontSize
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: slackRunning ? "Focus Slack" : "Launch Slack"
                            color: Theme.colFg
                            font.pixelSize: Theme.fontSize - 1
                            font.family: Theme.fontFamily
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
                            font.pixelSize: Theme.fontSize
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: "Clear notifications"
                            color: Theme.colFg
                            font.pixelSize: Theme.fontSize - 1
                            font.family: Theme.fontFamily
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
}
