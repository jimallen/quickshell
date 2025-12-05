import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Item {
    id: btWidget
    Layout.preferredWidth: btText.width
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 8

    required property var barWindow

    Connections {
        target: barWindow
        function onCloseAllPopups() {
            btDropdownOpen = false
        }
    }

    property bool btPowered: false
    property bool btConnected: false
    property string btConnectedDevice: ""
    property var btDevices: []
    property bool btDropdownOpen: false

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
                btWidget.btPowered = output.includes("Powered: yes")
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
                    btWidget.btConnected = true
                    var nameMatch = output.match(/Name:\s*(.+)/)
                    if (nameMatch) {
                        btWidget.btConnectedDevice = nameMatch[1].trim()
                    }
                } else {
                    btWidget.btConnected = false
                    btWidget.btConnectedDevice = ""
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
                btWidget.btDevices = devices
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

    // Update timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            btStatusProc.running = true
            btConnectedProc.running = true
        }
    }

    Text {
        id: btText
        anchors.centerIn: parent
        text: !btPowered ? "󰂲" :
              btConnected ? "󰂱" : "󰂯"
        color: btPowered ? (btConnected ? Theme.colBluetooth : Theme.colBluetooth) : Theme.colMuted
        font.pixelSize: Theme.fontSize + 4
        font.family: Theme.fontFamily
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

    // Focus grab to close popup when clicking outside
    HyprlandFocusGrab {
        id: btFocusGrab
        windows: [btPopup]
        active: btDropdownOpen
        onCleared: btDropdownOpen = false
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
            color: Theme.colBg
            radius: 10
            border.color: Theme.colMuted
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
                        color: Theme.colFg
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 40
                        height: 20
                        radius: 10
                        color: btPowered ? Theme.colBluetooth : Theme.colMuted

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            color: Theme.colFg
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
                    color: Theme.colMuted
                }

                // Paired devices header
                Text {
                    text: "Paired Devices"
                    color: Theme.colMuted
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
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
                                color: Theme.colBluetooth
                                font.pixelSize: Theme.fontSize
                                font.family: Theme.fontFamily
                            }

                            Text {
                                text: modelData.name
                                color: modelData.name === btConnectedDevice ? Theme.colBluetooth : Theme.colFg
                                font.pixelSize: Theme.fontSize - 1
                                font.family: Theme.fontFamily
                                font.bold: modelData.name === btConnectedDevice
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.name === btConnectedDevice ? "Connected" : ""
                                color: Theme.colBluetooth
                                font.pixelSize: Theme.fontSize - 3
                                font.family: Theme.fontFamily
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
                    color: Theme.colMuted
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
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
}
