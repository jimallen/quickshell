# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Quickshell configuration for a Hyprland Wayland desktop bar. The config uses QML with Quickshell-specific modules, organized into modular components.

## Commands

```bash
# Restart quickshell to apply changes
pkill -x quickshell; sleep 0.5; quickshell &

# Test weather script (uses ~/.config/hypr/UserScripts/Weather.py)
~/.config/hypr/UserScripts/Weather.py | jq -r '.text'
```

## Architecture

### File Structure

```
shell.qml           # Main entry point, assembles the bar layout
Theme.qml           # Singleton with colors, fonts, and theme settings
qmldir              # QML module definition for Theme singleton
components/         # Modular widget components
  ├── DropdownWidget.qml   # Base component for click-to-open dropdown widgets
  ├── WeatherStatItem.qml  # Reusable stat row for weather popup
  ├── WorkspaceBar.qml     # Hyprland workspaces with app icons (pill-shaped)
  ├── WindowInfo.qml       # Current window title
  ├── CenterInfo.qml       # Date/weather with hover popup showing detailed forecast
  ├── SystemStats.qml      # CPU, memory, disk, volume, battery
  ├── Clock.qml            # Time display
  ├── WifiWidget.qml       # WiFi status with dropdown (extends DropdownWidget)
  ├── BluetoothWidget.qml  # Bluetooth status with dropdown (extends DropdownWidget)
  ├── PowerProfileWidget.qml # Power profile selector (extends DropdownWidget)
  ├── SlackWidget.qml      # Slack indicator, click to focus app
  ├── WhatsAppWidget.qml   # WhatsApp indicator, click to focus app
  └── Separator.qml        # Visual separator line
```

### Key Components

- **Theme.qml**: Singleton pragma provides `Theme.colBg`, `Theme.fontSize`, etc. to all components
- **WorkspaceBar.qml**: Pill-shaped workspace indicators with numbers and deduplicated app icons (max 3). Hover effects and active state highlighting
- **CenterInfo.qml**: Date and weather text; hover shows popup with location, temperature, condition, feels-like, min/max, wind, humidity, visibility, AQI (color-coded), and hourly rain forecast bars
- **Widget components**: Each has its own Process components for data fetching and PopupWindow for dropdowns

### Key Patterns

- **Process + SplitParser**: All system data comes from shell commands via `Process` components with `SplitParser` for output
- **Theme singleton**: Components access theme via `import ".."` then use `Theme.colFg`, `Theme.fontSize`, etc.
- **PopupWindows**: Dropdowns use `PopupWindow` with `visible` bound to `*DropdownOpen` properties
- **HyprlandFocusGrab**: Used to close popups when clicking outside. Requires `import Quickshell.Hyprland`. Example:
  ```qml
  HyprlandFocusGrab {
      id: myFocusGrab
      windows: [myPopup]
      active: myDropdownOpen
      onCleared: myDropdownOpen = false
  }
  ```
- **Nerd Font Icons**: Uses Material Design Icons range (nf-md-*) which render correctly in Qt. Other ranges may not work.

### External Dependencies

- `nmcli` for WiFi scanning/connecting
- `bluetoothctl` for Bluetooth management
- `powerprofilesctl` for power profile management
- `dunstctl` for notification counts (Slack/WhatsApp unread)
- `hyprctl` for workspace/window data
- `jq` for JSON parsing
- `~/.config/hypr/UserScripts/Weather.py` for weather data (outputs JSON with `text` field)

### Adding New Widgets

1. Create a new component in `components/` (e.g., `MyWidget.qml`)
2. Add Process components for data fetching with SplitParser
3. Use `import ".."` to access Theme singleton
4. Add the component to shell.qml's RowLayout
5. For dropdowns, extend `DropdownWidget`:
   ```qml
   DropdownWidget {
       id: myWidget
       popupWidth: 200
       popupHeight: 150
       popupXOffset: 250  // from right edge of bar

       // Icon content (default property - what shows in bar)
       Text {
           anchors.verticalCenter: parent.verticalCenter
           text: "󰤨"
           color: Theme.colFg
       }

       // Popup content (use myWidget.* for property references)
       popupContent: Component {
           Column {
               Text { text: myWidget.someProperty }
           }
       }

       // Optional: React to dropdown opening
       onOpened: someProcess.running = true
   }
   ```
   The base component handles: barWindow connection, dropdownOpen state, MouseArea toggle, HyprlandFocusGrab, and PopupWindow with styled Rectangle container.
- no need to restart quickshell, it hot reloads the config on save.