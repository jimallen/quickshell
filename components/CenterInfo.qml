import QtQuick
import Quickshell.Io
import ".."

Text {
    id: centerInfo

    property string centerDate: Qt.formatDateTime(new Date(), "ddd, MMM d")
    property string weatherText: ""

    text: centerDate + (weatherText ? "  |  " + weatherText : "")
    color: Theme.colFg
    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    font.bold: true

    // Weather process
    Process {
        id: weatherProc
        command: ["sh", "-c", "$HOME/.config/hypr/UserScripts/Weather.py 2>/dev/null | jq -r '.text // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    centerInfo.weatherText = data.trim()
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Date update timer
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: centerDate = Qt.formatDateTime(new Date(), "ddd, MMM d")
    }

    // Weather timer (hourly updates)
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: weatherProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            centerInfo.weatherText = ""
            weatherProc.running = true
        }
    }
}
