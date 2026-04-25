# Vimursor

An open-source tool for controlling macOS entirely with the keyboard. Leveraging the Accessibility API, it allows you to click UI elements and scroll through pages without ever touching the mouse.

Not available on the App Store (distributed outside the sandbox due to Accessibility API requirements).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/kodakoda-koda/Vimursor/actions/workflows/ci.yml/badge.svg)](https://github.com/kodakoda-koda/Vimursor/actions/workflows/ci.yml)

---

<!-- TODO: Add screenshot/GIF demonstrating hint mode -->

## Features

| Shortcut | Feature |
|----------|---------|
| `Cmd+Shift+Space` | **Hint Mode** — Overlays labels on all clickable elements; press the corresponding keys to click |
| `Cmd+Shift+/` | **Search Mode** — Filter elements by typing text, then press Enter to click |
| `Cmd+Shift+J` | **Scroll Mode** — Scroll with keyboard keys |

Shortcuts can be changed via the menu bar icon → "Preferences...".

### Hint Mode

<!-- TODO: Add GIF demonstrating hint mode -->

1. Press `Cmd+Shift+Space` to display labels (`A`, `B`, `SA`, etc.) on all clickable elements
2. Type the keys shown on the label (e.g., press `S` then `A`)
3. The corresponding element is clicked automatically and Hint Mode exits
4. Press `ESC` to cancel

### Search Mode

<!-- TODO: Add GIF demonstrating search mode -->

1. Press `Cmd+Shift+/` to open a search bar at the bottom of the screen
2. Type text to filter and narrow down the target element
3. Press `Enter` to click the first match
4. Press `ESC` to cancel

### Scroll Mode

<!-- TODO: Add GIF demonstrating scroll mode -->

1. Press `Cmd+Shift+J` to enter Scroll Mode
2. Use the following keys to scroll:
   - `j` — scroll down
   - `k` — scroll up
   - `d` — scroll down half a page
   - `u` — scroll up half a page
3. Press `ESC` to exit Scroll Mode

---

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0 or later (only required when building from source)

---

## Installation

### Download from GitHub Releases (recommended)

1. Download the latest `Vimursor.dmg` from the [Releases page](https://github.com/kodakoda-koda/Vimursor/releases)
2. Open the DMG and drag `Vimursor.app` to the `/Applications` folder
3. Launch `Vimursor.app` (a Gatekeeper warning may appear on first launch)
   - If a warning appears: right-click → "Open" → "Open"

### Build from Source

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor

# Generate the .app bundle
bash scripts/build-app.sh

# Launch
open Vimursor.app
```

### Granting Accessibility Permission

Vimursor uses the Accessibility API, so you must grant permission on first launch.

1. Launch Vimursor (a system dialog will appear at startup)
2. Open "System Settings" → "Privacy & Security" → "Accessibility"
3. Confirm that `Vimursor` appears in the list and enable its toggle

> Hotkeys will not respond unless the permission is granted.

---

## Troubleshooting

### Hotkeys are not responding

Check that Accessibility permission has been granted.

1. Open "System Settings" → "Privacy & Security" → "Accessibility"
2. Confirm that `Vimursor` is checked
3. If it is checked but still not working, try removing it from the list and re-adding it (see below)

### Granted permission but still not working

Re-registering the permission often resolves the issue.

1. Open "System Settings" → "Privacy & Security" → "Accessibility"
2. Remove `Vimursor` from the list using the `-` button on the left
3. Restart Vimursor — the permission dialog will appear again; grant permission once more

### Labels are not appearing

- Make sure the target window has keyboard focus
- Some apps (such as Electron-based apps) do not support the Accessibility API, so labels may not appear

---

## Development

```bash
swift build          # debug build
swift test           # run tests
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

---

## License

[MIT License](LICENSE)
