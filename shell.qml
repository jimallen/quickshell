//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "components"

ShellRoot {
    id: root

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
                color: Theme.colBgTransparent
                radius: 10

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Left padding
                    Item { width: 8 }

                    // Logo
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

                    // Workspaces
                    WorkspaceBar {
                        Layout.preferredHeight: parent.height
                    }

                    // Separator
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: Theme.colMuted
                    }

                    // Window info (layout + title)
                    WindowInfo {
                        Layout.preferredHeight: parent.height
                    }

                    // Left spacer
                    Item { Layout.fillWidth: true }

                    // Center: Date and Weather
                    CenterInfo {}

                    // Right spacer
                    Item { Layout.fillWidth: true }

                    // Slack indicator
                    SlackWidget {
                        barWindow: barWindow
                    }

                    // WhatsApp indicator
                    WhatsAppWidget {
                        barWindow: barWindow
                    }

                    Separator {}

                    // System stats (CPU, Memory, Disk, Volume, Battery)
                    SystemStats {
                        Layout.preferredHeight: parent.height
                    }

                    Separator {}

                    // WiFi indicator
                    WifiWidget {
                        barWindow: barWindow
                    }

                    // Bluetooth indicator
                    BluetoothWidget {
                        barWindow: barWindow
                    }

                    Separator {}

                    // Clock
                    Clock {
                        Layout.rightMargin: 8
                    }

                    // Right padding
                    Item { width: 8 }
                }
            }
        }
    }
}
