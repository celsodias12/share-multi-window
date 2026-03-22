# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Share Multi Window is a native macOS app (Swift/SwiftUI, macOS 14+) that lets users select multiple desktop windows and compose them into a single shareable view. The primary use case is screen sharing during calls — instead of sharing an entire screen, users pick specific windows and the app shows the currently focused one in a composite window that can be shared via any conferencing tool.

The UI language is Portuguese (pt-BR).

## Build & Run

```bash
make build       # Compiles with swift build -c release
make app         # Builds + creates .app bundle with codesign
make run         # Builds app + opens it
make dmg         # Creates distributable DMG installer
make install     # Copies .app to /Applications
make uninstall   # Removes from /Applications
make clean       # Removes .build, .app, .dmg, build/
```

The project uses Swift Package Manager (`Package.swift`) — no Xcode project file. Build artifacts go to `.build/`.

## Architecture

**Two-window design:**
- **Control window** (`ContentView.swift`) — shows available desktop windows grouped by app in a 2-column grid with live thumbnails. Users select/deselect windows here.
- **Composite window** (`CompositeView.swift`) — displays the currently focused selected window full-size on a black background. This is the window meant to be shared in calls. Has hover-reveal controls for stopping or switching back to selection.

**Core engine** (`WindowCaptureManager.swift`) — `@Observable` singleton that handles everything:
- Window enumeration via `SCShareableContent` (filters out system windows, tiny windows, own app)
- Groups windows by app into `AppGroup` structs for Discord-style UI grouping
- Preview generation via `SCScreenshotManager` (low-res thumbnails, refreshed every 2s)
- Live capture via `SCStream` at 15fps per selected window (full resolution)
- Focus tracking via `CGWindowListCopyWindowInfo` polling (every 0.3s) to determine which selected window is frontmost → `activeWindowID`
- Maintains `frames` dict (live SCStream images) and `previews` dict (screenshot thumbnails)

**Data flow:** `SCShareableContent` → `WindowInfo` (lightweight model) + `SCWindow` refs cached → user selects → `SCStream` starts → frames update → `CompositeView` shows `activeWindowID` frame.

**Key design decisions:**
- `WindowInfo` is decoupled from `SCWindow` to keep the view layer framework-agnostic
- `StreamOutput` bridges `SCStreamOutput` delegate to a closure-based callback
- Focus tracking uses CGWindowList (front-to-back ordering) rather than NSWorkspace notifications for reliability
- The app requires Screen Recording permission (`NSScreenCaptureUsageDescription` in Info.plist)

## Key Files

- `App.swift` — App entry point, declares both windows, injects `WindowCaptureManager` via `.environment()`
- `AppDelegate.swift` — Handles dock icon click to reopen control window
- `WindowCaptureManager.swift` — All capture/state logic (~400 lines, the core of the app)
- `ContentView.swift` — Window selection UI with `WindowCard` and `GradientButtonStyle`
- `CompositeView.swift` — Shared screen output with hover controls
- `Info.plist` — Bundle config including screen capture permission string
- `create-dmg.sh` — DMG packaging script with Finder layout via AppleScript
