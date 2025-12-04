import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

Item {
    id: wifiWidget
    Layout.preferredWidth: wifiText.width
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 8

    required property var barWindow

    property string wifiSSID: ""
    property int wifiSignal: 0
    property bool wifiConnected: false
    property var wifiNetworks: []
    property bool wifiDropdownOpen: false

    // WiFi current connection
    Process {
        id: wifiCurrentProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list | grep '^yes' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) {
                    wifiWidget.wifiConnected = false
                    wifiWidget.wifiSSID = ""
                    wifiWidget.wifiSignal = 0
                    return
                }
                var parts = data.trim().split(':')
                if (parts.length >= 3) {
                    wifiWidget.wifiConnected = true
                    wifiWidget.wifiSSID = parts[1]
                    wifiWidget.wifiSignal = parseInt(parts[2]) || 0
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
                wifiWidget.wifiNetworks = networks
            }
        }
    }

    // WiFi connect process
    Process {
        id: wifiConnectProc
        property string targetSSID: ""
        command: ["nmcli", "device", "wifi", "connect", targetSSID]
    }

    // Update timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: wifiCurrentProc.running = true
    }

    Text {
        id: wifiText
        anchors.centerIn: parent
        text: !wifiConnected ? "󰤭" :
              wifiSignal >= 80 ? "󰤨" :
              wifiSignal >= 60 ? "󰤥" :
              wifiSignal >= 40 ? "󰤢" :
              wifiSignal >= 20 ? "󰤟" : "󰤯"
        color: wifiConnected ? Theme.colNetwork : Theme.colMuted
        font.pixelSize: Theme.fontSize + 4
        font.family: Theme.fontFamily
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
            color: Theme.colBg
            radius: 10
            border.color: Theme.colMuted
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header
                Text {
                    text: wifiConnected ? "󰤨 " + wifiSSID : "󰤭 Not Connected"
                    color: Theme.colFg
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                    font.bold: true
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.colMuted
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
                                color: Theme.colNetwork
                                font.pixelSize: Theme.fontSize
                                font.family: Theme.fontFamily
                            }

                            Text {
                                text: modelData.ssid
                                color: modelData.ssid === wifiSSID ? Theme.colNetwork : Theme.colFg
                                font.pixelSize: Theme.fontSize - 1
                                font.family: Theme.fontFamily
                                font.bold: modelData.ssid === wifiSSID
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.security ? "󰌾" : ""
                                color: Theme.colMuted
                                font.pixelSize: Theme.fontSize - 2
                                font.family: Theme.fontFamily
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
}
