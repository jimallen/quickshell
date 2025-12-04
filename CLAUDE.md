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
  ├── WorkspaceBar.qml   # Hyprland workspaces with app icons
  ├── WindowInfo.qml     # Current window layout and title
  ├── CenterInfo.qml     # Date and weather display
  ├── SystemStats.qml    # CPU, memory, disk, volume, battery
  ├── Clock.qml          # Time display
  ├── WifiWidget.qml     # WiFi status with dropdown
  ├── BluetoothWidget.qml # Bluetooth status with dropdown
  ├── SlackWidget.qml    # Slack notification indicator
  ├── WhatsAppWidget.qml # WhatsApp notification indicator
  └── Separator.qml      # Visual separator line
```

### Key Components

- **Theme.qml**: Singleton pragma provides `Theme.colBg`, `Theme.fontSize`, etc. to all components
- **WorkspaceBar.qml**: Shows workspace numbers with deduplicated app icons (up to 4 per workspace). Uses `hyprctl clients -j | jq` for window data
- **Widget components**: Each has its own Process components for data fetching and PopupWindow for dropdowns

### Key Patterns

- **Process + SplitParser**: All system data comes from shell commands via `Process` components with `SplitParser` for output
- **Theme singleton**: Components access theme via `import ".."` then use `Theme.colFg`, `Theme.fontSize`, etc.
- **PopupWindows**: Dropdowns use `PopupWindow` with `visible` bound to `*DropdownOpen` properties
- **Nerd Font Icons**: Uses Material Design Icons range (nf-md-*) which render correctly in Qt. Other ranges may not work.

### External Dependencies

- `nmcli` for WiFi scanning/connecting
- `bluetoothctl` for Bluetooth management
- `dunstctl` for notification counts (Slack/WhatsApp unread)
- `hyprctl` for workspace/window data
- `jq` for JSON parsing
- `~/.config/hypr/UserScripts/Weather.py` for weather data (outputs JSON with `text` field)

### Adding New Widgets

1. Create a new component in `components/` (e.g., `MyWidget.qml`)
2. Add Process components for data fetching with SplitParser
3. Use `import ".."` to access Theme singleton
4. Add the component to shell.qml's RowLayout
5. For dropdowns: Add PopupWindow and wire up a `*DropdownOpen` property
