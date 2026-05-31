# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

A native macOS menubar app that lets the user search Tenor GIFs and drag them directly into Slack as real animated GIFs. No Dock icon. Summoned via menubar click or the global hotkey ⌥G.

## Building

Open `GifDropper.xcodeproj` in Xcode and press ⌘R. There is no CLI build flow — the user runs builds themselves in Xcode. Do not run `xcodebuild` unless explicitly asked.

## Swift 6 constraints (important)

The project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` in the build settings. This means:

- **Do not use `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject`** — they break under this isolation model. Use `@Observable` (Observation framework) + `@State` / `@Environment(Type.self)` instead.
- Methods called from C callbacks or background delegate callbacks must be `nonisolated`.
- C callbacks (Carbon hotkey handler) bridge to Swift via `NotificationCenter.default.post(...)` — calling MainActor-isolated code directly from a C callback will not compile.
- Properties read on a background thread (e.g. `NSFilePromiseProviderDelegate` callbacks) but written on the main thread must be marked `nonisolated(unsafe)`.

## Architecture

**AppDelegate** owns everything at the top level: `NSStatusItem`, `NSPopover`, the `Store` instance, and the Carbon hotkey registration. The popover's content is `PickerView` injected with `Store` via `.environment(store)`.

**The drag path is the critical feature.** `GifCell` renders a `DraggableGifView` (`NSViewRepresentable` wrapping `DragGifNSView`). On hover, `DragGifNSView.prefetchIfNeeded()` downloads the full GIF to `tmp/gippy/<id>_<name>.gif` in the background. On mouse drag, if the file is already on disk, it is handed to Slack as a concrete `NSURL` pasteboard writer — this registers `public.file-url` on the pasteboard, identical to dragging a file from Finder. `NSFilePromiseProvider` is kept as a fallback for when the download hasn't completed yet.

**Why concrete NSURL, not NSFilePromiseProvider?** Slack (Electron/Chromium) only accepts `public.file-url`. `NSFilePromiseProvider` registers `com.apple.pasteboard.promised-file-content-type` which Slack's drop zone rejects at hover time — `writePromiseTo` is never called and the drag bounces back.

**Popover freeze during drag:** `DragGifNSView` posts `gifDragBegan` / `gifDragEnded` notifications. `AppDelegate` observes these and switches `popover.behavior` between `.applicationDefined` (frozen) and `.transient` (auto-closes on click-outside). This prevents the popover from dismissing before Slack receives the file.

**`@Observable` types:** `Store` (recents + favourites, persisted to UserDefaults) and `ImageLoader` (per-cell, caches preview GIF bytes in a shared `NSCache`).

**GIF display:** SwiftUI `Image`/`AsyncImage` do not animate GIFs. `DragGifNSView` (inside `DraggableGifView: NSViewRepresentable`) contains an `NSImageView` with `animates = true`. Layout priorities on the NSImageView must stay `.defaultLow` on all axes — otherwise `LazyVGrid` triggers layout recursion warnings.

**Keychain:** The Tenor API key is stored under service `com.lavi.Gippy`, account key `tenorAPIKey`. `Keychain.read/write` are `nonisolated` static methods. The key is entered once in `SettingsView` (gear icon in the popover).

**Tenor API:** `GET https://tenor.googleapis.com/v2/search` with `media_filter=tinygif,gif`. `tinygif` is used for the preview grid (small, fast); `gif` is used for the drag payload (full quality).

## Known non-issues in Xcode logs

These appear at runtime and are harmless — do not try to fix them:
- `fopen failed for data file: errno = 2` — system SQLite
- `ViewBridge to RemoteViewService Terminated` — SwiftUI/AppKit bridge, benign
- `cannot open file … /private/var/db/DetachedSignatures` — codesign cache miss in dev builds
