import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

Item {
    id: whatsappWidget
    Layout.preferredWidth: whatsappText.width + (whatsappUnread > 0 ? 16 : 0)
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 8

    required property var barWindow

    property bool whatsappRunning: false
    property int whatsappUnread: 0
    property bool whatsappDropdownOpen: false

    // WhatsApp running check
    Process {
        id: whatsappRunningProc
        command: ["sh", "-c", "pgrep -f 'whatsapp|WhatsApp' >/dev/null && echo 'running' || echo 'stopped'"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    whatsappWidget.whatsappRunning = data.trim() === "running"
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
                    whatsappWidget.whatsappUnread = parseInt(data.trim()) || 0
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

    // Update timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            whatsappRunningProc.running = true
            whatsappUnreadProc.running = true
        }
    }

    Text {
        id: whatsappText
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: whatsappUnread > 0 ? -8 : 0
        text: "󰖣"
        color: whatsappRunning ? Theme.colWhatsapp : Theme.colMuted
        font.pixelSize: Theme.fontSize + 4
        font.family: Theme.fontFamily
        font.bold: true
    }

    // Unread badge
    Rectangle {
        visible: whatsappUnread > 0
        width: 14
        height: 14
        radius: 7
        color: Theme.colWhatsapp
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 6

        Text {
            anchors.centerIn: parent
            text: whatsappUnread > 9 ? "+" : whatsappUnread
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
        onClicked: whatsappDropdownOpen = !whatsappDropdownOpen
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
                        text: "󰖣 WhatsApp"
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
                        color: whatsappRunning ? Theme.colWhatsapp : Theme.colMuted
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.colMuted
                }

                // Status info
                Text {
                    text: whatsappRunning ? (whatsappUnread > 0 ? whatsappUnread + " unread notification" + (whatsappUnread > 1 ? "s" : "") : "No new notifications") : "WhatsApp is not running"
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
                    color: openWhatsappMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                    radius: 6

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: whatsappRunning ? "󰈈" : "󰐊"
                            color: Theme.colWhatsapp
                            font.pixelSize: Theme.fontSize
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: whatsappRunning ? "Focus WhatsApp" : "Launch WhatsApp"
                            color: Theme.colFg
                            font.pixelSize: Theme.fontSize - 1
                            font.family: Theme.fontFamily
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
                            color: Theme.colWhatsapp
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
