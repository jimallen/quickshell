import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

Item {
    id: root
    Layout.preferredWidth: iconContainer.width
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 8

    required property var barWindow
    property int popupWidth: 200
    property int popupHeight: 150
    property int popupXOffset: 200
    property bool dropdownOpen: false
    property alias popupContent: popupLoader.sourceComponent

    signal opened()

    default property alias iconContent: iconContainer.data

    Connections {
        target: barWindow
        function onCloseAllPopups() {
            dropdownOpen = false
        }
    }

    Row {
        id: iconContainer
        anchors.centerIn: parent
        height: parent.height
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            dropdownOpen = !dropdownOpen
            if (dropdownOpen) {
                root.opened()
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        active: dropdownOpen
        onCleared: dropdownOpen = false
    }

    PopupWindow {
        id: popup
        visible: dropdownOpen
        anchor.window: barWindow
        anchor.rect.x: barWindow.width - popupXOffset
        anchor.rect.y: 40
        implicitWidth: popupWidth
        implicitHeight: popupHeight
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.colBg
            radius: 10
            border.color: Theme.colMuted
            border.width: 1

            Loader {
                id: popupLoader
                anchors.fill: parent
                anchors.margins: 8
            }
        }

        onVisibleChanged: {
            if (!visible) {
                dropdownOpen = false
            }
        }
    }
}
