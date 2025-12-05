import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

Item {
    id: centerInfo
    implicitWidth: centerText.implicitWidth
    implicitHeight: parent.height

    required property var barWindow

    property string centerDate: Qt.formatDateTime(new Date(), "ddd, MMM d")
    property string weatherText: ""
    property string weatherIcon: ""
    property string weatherCondition: ""
    property string weatherLocation: ""
    property string weatherFeelsLike: ""
    property string weatherMinTemp: ""
    property string weatherMaxTemp: ""
    property string weatherWind: ""
    property string weatherHumidity: ""
    property string weatherVisibility: ""
    property string weatherAqi: ""
    property var hourlyRain: []

    property bool popupVisible: false
    property bool dndEnabled: false

    // DND status check
    Process {
        id: dndStatusProc
        command: ["swaync-client", "-D"]
        stdout: SplitParser {
            onRead: data => {
                if (data) centerInfo.dndEnabled = data.trim() === "true"
            }
        }
        Component.onCompleted: running = true
    }

    // DND toggle process
    Process {
        id: dndToggleProc
        command: ["swaync-client", "-d"]
        onRunningChanged: {
            if (!running) dndStatusProc.running = true
        }
    }

    // DND status update timer
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: dndStatusProc.running = true
    }

    // Get color based on temperature (Celsius)
    function getTempColor(tempStr) {
        var match = tempStr.match(/-?\d+/)
        if (!match) return Theme.colFg
        var temp = parseInt(match[0])
        if (temp <= 0) return "#8be9fd"      // Freezing - cyan
        if (temp <= 10) return "#6db3f2"     // Cold - light blue
        if (temp <= 18) return "#50fa7b"     // Cool - green
        if (temp <= 25) return "#f1fa8c"     // Warm - yellow
        if (temp <= 32) return "#ffb86c"     // Hot - orange
        return "#ff5555"                      // Very hot - red
    }

    // Get color based on weather condition
    function getConditionColor(condition) {
        var cond = condition.toLowerCase()
        if (cond.includes("sun") || cond.includes("clear")) return "#f1fa8c"  // Yellow
        if (cond.includes("cloud") || cond.includes("overcast")) return "#94a3b8"  // Gray
        if (cond.includes("rain") || cond.includes("drizzle") || cond.includes("shower")) return "#8be9fd"  // Cyan
        if (cond.includes("thunder") || cond.includes("storm")) return "#bd93f9"  // Purple
        if (cond.includes("snow") || cond.includes("sleet") || cond.includes("ice")) return "#f8f8f2"  // White
        if (cond.includes("fog") || cond.includes("mist") || cond.includes("haze")) return "#6272a4"  // Muted blue
        if (cond.includes("wind")) return "#50fa7b"  // Green
        return Theme.colFg
    }

    // Parse weather JSON and update properties
    function parseWeatherJson(output) {
        try {
            var json = JSON.parse(output)
            centerInfo.weatherText = json.text || ""
            centerInfo.weatherCondition = json.alt || ""

            // Parse tooltip for detailed data
            if (json.tooltip) {
                var tooltip = json.tooltip
                // Extract location (first line, inside <b> tags)
                var locMatch = tooltip.match(/<b>([^<]+)<\/b>/)
                if (locMatch) centerInfo.weatherLocation = locMatch[1]

                // Extract feels like
                var feelsMatch = tooltip.match(/Feels like ([^<]+)/)
                if (feelsMatch) centerInfo.weatherFeelsLike = feelsMatch[1]

                // Extract icon (big text after condition)
                var iconMatch = tooltip.match(/<big>([^<]+)<\/big>/)
                if (iconMatch) centerInfo.weatherIcon = iconMatch[1].trim()

                // Extract min/max temps (line with two temps)
                var tempMatch = tooltip.match(/([^\t]+)\t\t([^\n<]+)/)
                if (tempMatch) {
                    // Look for the line with min/max
                    var lines = tooltip.split('\n')
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]
                        // Match pattern like "  1°		  3°"
                        var minMaxMatch = line.match(/\s*([^\t]+)\t\t\s*([^\t\n]+)/)
                        if (minMaxMatch && minMaxMatch[1].includes('°') && minMaxMatch[2].includes('°')) {
                            centerInfo.weatherMinTemp = minMaxMatch[1].trim()
                            centerInfo.weatherMaxTemp = minMaxMatch[2].trim()
                        }
                        // Wind and humidity line
                        if (line.includes('km/h') && line.includes('%')) {
                            var parts = line.split('\t').filter(p => p.trim())
                            if (parts.length >= 2) {
                                centerInfo.weatherWind = parts[0].trim()
                                centerInfo.weatherHumidity = parts[1].trim()
                            }
                        }
                        // Visibility and AQI
                        if (line.includes('km') && line.includes('AQI')) {
                            var visParts = line.split('\t').filter(p => p.trim())
                            if (visParts.length >= 2) {
                                centerInfo.weatherVisibility = visParts[0].trim()
                                var aqiMatch = line.match(/AQI\s*(\d+)/)
                                if (aqiMatch) centerInfo.weatherAqi = aqiMatch[1]
                            }
                        }
                    }
                }

                // Extract hourly rain chances
                var rainMatch = tooltip.match(/Rain drop (\d+)%/g)
                if (rainMatch) {
                    var rainArr = []
                    for (var j = 0; j < rainMatch.length && j < 5; j++) {
                        var pct = rainMatch[j].match(/(\d+)/)
                        if (pct) rainArr.push(parseInt(pct[1]))
                    }
                    centerInfo.hourlyRain = rainArr
                }
            }
            return true
        } catch (e) {
            return false
        }
    }

    Row {
        id: centerText
        anchors.centerIn: parent
        spacing: 0

        // Weather text parts extracted from weatherText (format: "icon temp° location")
        property string barIcon: {
            if (!weatherText) return ""
            var match = weatherText.match(/^(\S+)\s/)
            return match ? match[1] : ""
        }
        property string barTemp: {
            if (!weatherText) return ""
            var match = weatherText.match(/-?\d+°/)
            return match ? match[0] : ""
        }
        property string barLocation: {
            if (!weatherText) return ""
            var match = weatherText.match(/-?\d+°\s*(.+)$/)
            return match ? match[1] : ""
        }

        // DND toggle
        Text {
            text: dndEnabled ? "󰂛  " : "󰂚  "
            color: dndEnabled ? "#ff5555" : Theme.colMuted
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: dndToggleProc.running = true
            }
        }

        Text {
            text: centerDate
            color: Theme.colFg
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Text {
            visible: weatherText !== ""
            text: "  |  "
            color: Theme.colMuted
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Text {
            visible: centerText.barIcon !== ""
            text: centerText.barIcon + " "
            color: getTempColor(weatherText)
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Text {
            visible: centerText.barTemp !== ""
            text: centerText.barTemp
            color: getTempColor(weatherText)
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Text {
            visible: centerText.barLocation !== ""
            text: " " + centerText.barLocation
            color: Theme.colFg
            font.pixelSize: Theme.fontSize
            font.family: Theme.fontFamily
            font.bold: true
        }
    }

    // Weather process - fetch full JSON
    Process {
        id: weatherProc
        property string output: ""
        command: ["sh", "-c", "$HOME/.config/hypr/UserScripts/Weather.py 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                if (data) weatherProc.output += data
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else if (output) {
                if (parseWeatherJson(output)) {
                    // Save to cache on successful fetch
                    saveWeatherCache(output)
                }
            }
            // If no output (offline), cached data remains displayed
        }
        Component.onCompleted: {
            // First load from cache, then fetch fresh data
            cacheReadProc.running = true
        }
    }

    // Function to save weather cache
    function saveWeatherCache(data) {
        // Escape single quotes in JSON for shell
        var escaped = data.replace(/'/g, "'\\''")
        cacheWriteProc.command = ["sh", "-c", "mkdir -p ~/.cache/quickshell && printf '%s' '" + escaped + "' > ~/.cache/quickshell/weather.json"]
        cacheWriteProc.running = true
    }

    // Cache write process
    Process {
        id: cacheWriteProc
    }

    // Cache read process
    Process {
        id: cacheReadProc
        property string output: ""
        command: ["sh", "-c", "cat ~/.cache/quickshell/weather.json 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: data => {
                if (data) cacheReadProc.output += data
            }
        }
        onRunningChanged: {
            if (running) {
                output = ""
            } else {
                // Load cached data first
                if (output) {
                    parseWeatherJson(output)
                }
                // Then try to fetch fresh data
                weatherProc.running = true
            }
        }
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
        cursorShape: weatherText ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (weatherText) {
                centerInfo.popupVisible = !centerInfo.popupVisible
            }
        }
    }

    HyprlandFocusGrab {
        id: weatherFocusGrab
        windows: [weatherPopup]
        active: centerInfo.popupVisible
        onCleared: centerInfo.popupVisible = false
    }

    // Weather popup
    PopupWindow {
        id: weatherPopup
        visible: centerInfo.popupVisible && centerInfo.weatherText
        anchor.window: barWindow
        anchor.rect.x: (barWindow.width - 280) / 2
        anchor.rect.y: 40
        implicitWidth: 280
        implicitHeight: contentColumn.implicitHeight + 32
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.colBg
            radius: 12
            border.color: Qt.rgba(Theme.colMuted.r, Theme.colMuted.g, Theme.colMuted.b, 0.5)
            border.width: 1

            // Subtle gradient overlay
            Rectangle {
                anchors.fill: parent
                radius: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.03) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            MouseArea {
                id: popupMouse
                anchors.fill: parent
            }

            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header: Location
                Text {
                    text: centerInfo.weatherLocation || "Weather"
                    color: Theme.colMuted
                    font.pixelSize: Theme.fontSize - 2
                    font.family: Theme.fontFamily
                    width: parent.width
                    elide: Text.ElideRight
                }

                // Main weather display
                RowLayout {
                    width: parent.width
                    spacing: 16

                    // Large icon
                    Text {
                        text: centerInfo.weatherIcon || ""
                        color: getConditionColor(centerInfo.weatherCondition)
                        font.pixelSize: 48
                        font.family: Theme.fontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Temp and condition
                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        // Extract just the temperature from weatherText
                        Text {
                            property string temp: {
                                var match = centerInfo.weatherText.match(/-?\d+/)
                                return match ? match[0] + "°" : centerInfo.weatherText
                            }
                            text: temp
                            color: getTempColor(centerInfo.weatherText)
                            font.pixelSize: 36
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        Text {
                            text: centerInfo.weatherCondition
                            color: Theme.colMuted
                            font.pixelSize: Theme.fontSize
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: centerInfo.weatherFeelsLike ? "Feels " + centerInfo.weatherFeelsLike : ""
                            color: Qt.rgba(Theme.colMuted.r, Theme.colMuted.g, Theme.colMuted.b, 0.7)
                            font.pixelSize: Theme.fontSize - 2
                            font.family: Theme.fontFamily
                            visible: centerInfo.weatherFeelsLike !== ""
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.colMuted.r, Theme.colMuted.g, Theme.colMuted.b, 0.3)
                }

                // Stats grid
                GridLayout {
                    width: parent.width
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 16

                    // Min/Max
                    WeatherStatItem {
                        icon: ""
                        label: "Low"
                        value: centerInfo.weatherMinTemp
                        valueColor: getTempColor(centerInfo.weatherMinTemp)
                        visible: centerInfo.weatherMinTemp !== ""
                    }
                    WeatherStatItem {
                        icon: ""
                        label: "High"
                        value: centerInfo.weatherMaxTemp
                        valueColor: getTempColor(centerInfo.weatherMaxTemp)
                        visible: centerInfo.weatherMaxTemp !== ""
                    }

                    // Wind and Humidity
                    WeatherStatItem {
                        icon: ""
                        label: "Wind"
                        value: centerInfo.weatherWind
                        visible: centerInfo.weatherWind !== ""
                    }
                    WeatherStatItem {
                        icon: ""
                        label: "Humidity"
                        value: centerInfo.weatherHumidity
                        visible: centerInfo.weatherHumidity !== ""
                    }

                    // Visibility and AQI
                    WeatherStatItem {
                        icon: "󰈈"
                        label: "Visibility"
                        value: centerInfo.weatherVisibility
                        visible: centerInfo.weatherVisibility !== ""
                    }
                    WeatherStatItem {
                        icon: "󰵃"
                        label: "AQI"
                        value: centerInfo.weatherAqi
                        valueColor: {
                            var aqi = parseInt(centerInfo.weatherAqi)
                            if (aqi <= 50) return "#50fa7b"
                            if (aqi <= 100) return "#f1fa8c"
                            if (aqi <= 150) return "#ffb86c"
                            return "#ff5555"
                        }
                        visible: centerInfo.weatherAqi !== ""
                    }
                }

                // Hourly rain forecast
                Column {
                    width: parent.width
                    spacing: 6
                    visible: centerInfo.hourlyRain.length > 0

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.colMuted.r, Theme.colMuted.g, Theme.colMuted.b, 0.3)
                    }

                    Text {
                        text: " Rain Chance (hourly)"
                        color: Theme.colMuted
                        font.pixelSize: Theme.fontSize - 2
                        font.family: Theme.fontFamily
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: centerInfo.hourlyRain

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                color: Qt.rgba(Theme.colNetwork.r, Theme.colNetwork.g, Theme.colNetwork.b, 0.1)
                                radius: 4

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height * (modelData / 100)
                                    color: Qt.rgba(Theme.colNetwork.r, Theme.colNetwork.g, Theme.colNetwork.b, 0.4 + (modelData / 200))
                                    radius: 4
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "%"
                                    color: Theme.colFg
                                    font.pixelSize: 9
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
