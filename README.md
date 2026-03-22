# Share Multi Window

A native macOS app that lets you share specific windows during video calls instead of your entire screen.

Pick the windows you want to share, and the app displays whichever one is currently in focus — automatically switching as you move between them. Share the composite window in any conferencing tool (Zoom, Google Meet, Discord, etc.) for a clean, focused screen share.

## Requirements

- macOS 14.0 (Sonoma) or later
- Screen Recording permission (the app will prompt you on first launch)

## Install

### From DMG

Download the `.dmg` from [Releases](../../releases), open it, and drag **Share Multi Window** to Applications.

### From source

```bash
git clone <repo-url>
cd share-multi-window
make install
```

## Usage

1. Launch **Share Multi Window**
2. Grant Screen Recording permission when prompted (System Settings → Privacy & Security → Screen Recording)
3. Select the windows you want to share by clicking their thumbnails
4. Click **Compartilhar** to open the composite window
5. In your video call app, share the **Tela Compartilhada** window
6. The composite window automatically shows whichever selected window is in focus

Hover over the composite window to reveal controls for stopping or going back to window selection.

## Build

```bash
make build     # Compile release binary
make app       # Build + create .app bundle
make run       # Build + launch the app
make dmg       # Create distributable DMG installer
make clean     # Remove all build artifacts
```

Requires Swift 5.9+ (included with Xcode 15+). No Xcode project needed — builds with Swift Package Manager.

## How it works

The app uses Apple's [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) to enumerate and capture windows. It runs two windows:

- **Control window** — lists all open windows grouped by app with live thumbnails, lets you select which ones to include
- **Composite window** — displays the currently focused selected window at full resolution, meant to be shared in calls

Focus tracking polls the system window list to detect which selected window is frontmost, switching the display automatically.

## License

Copyright 2026. All rights reserved.
