# FocusBlur

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A native macOS menu bar app that blurs and dims everything except the active window, helping you focus.

Free, open-source alternative to [Muffle](https://www.getmuffle.com/).

## Features

- **Blur inactive windows** — GPU-accelerated Gaussian blur (adjustable 0–30)
- **Dim inactive windows** — semi-transparent dark overlay (adjustable 0–100%)
- **Shake cursor to toggle** — rapidly shake your mouse to enable/disable
- **Menu bar only** — lives in your menu bar, no Dock icon clutter
- **Multi-display support** — one overlay per screen, tracks the active window across displays
- **Launch at login** — optional, via macOS native login items
- **Zero CPU at idle** — event-driven architecture, no polling when nothing changes

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/danielaustralia1/FocusBlur.git
   cd FocusBlur/FocusBlur
   ```

2. Open in Xcode:
   ```bash
   open FocusBlur.xcodeproj
   ```

3. Build and run (⌘R)

4. **Grant Accessibility permissions** when prompted, or manually:
   - System Settings → Privacy & Security → Accessibility
   - Add and enable FocusBlur

## How It Works

FocusBlur places a transparent overlay window on each display that sits above inactive windows but below the active one. The overlay applies a `CIGaussianBlur` filter via `CALayer.backgroundFilters` (GPU-composited) and a semi-transparent black tint for dimming. A rectangular cutout in the overlay lets the active window show through unblurred and undimmed.

The app uses the macOS Accessibility API (`AXUIElement`) to track the frontmost window's position and size in real time.

## Permissions

- **Accessibility** — Required to track the active window's frame via AXUIElement
- **Screen Recording** — Not required (uses CALayer background filters, not screen capture)

## Credits

Inspired by [Blurred](https://github.com/dwarvesf/blurred) by Dwarves Foundation and [Muffle](https://www.getmuffle.com/) by Abjcodes.

## License

MIT License — see [LICENSE](LICENSE) for details.
