# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

A native macOS menubar app that lets the user search Tenor GIFs and drag them directly into Slack as real animated GIFs. No Dock icon. Summoned via menubar click or the global hotkey ⌥G.

## Building

Open `GifDropper.xcodeproj` in Xcode and press ⌘R. There is no CLI build flow — the user runs builds themselves in Xcode. Do not run `xcodebuild` unless explicitly asked.

## Swift 6 constraints (important)

The project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` in the build settings. This means:

- **Do not use `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject`** — they break under this isolation model. Use `@Observable` (Observation framework) + `@State` / `@Environment(Type.self)` instead.
- Methods called from C callbacks or `NSItemProvider` background callbacks must be `nonisolated`.
- C callbacks (Carbon hotkey handler) bridge to Swift via `NotificationCenter.default.post(...)` — calling MainActor-isolated code directly from a C callback will not compile.

## Architecture

**AppDelegate** owns everything at the top level: `NSStatusItem`, `NSPopover`, the `Store` instance, and the Carbon hotkey registration. The popover's content is `PickerView` injected with `Store` via `.environment(store)`.

**The drag path is the critical feature.** `GifCell.onDrag` → `DragProvider.itemProvider(for:)` → `NSItemProvider.registerFileRepresentation` → downloads the full GIF to `tmp/gifdropper/<id>.gif` → hands Slack a real `.gif` file. If Slack ever receives a link instead of a file, the problem is in `DragProvider`. The file must be written to `FileManager.default.temporaryDirectory` (sandbox-accessible).

**`@Observable` types:** `Store` (recents + favourites, persisted to UserDefaults) and `ImageLoader` (per-cell, caches preview GIF bytes in a shared `NSCache`).

**GIF display:** SwiftUI `Image`/`AsyncImage` do not animate GIFs. `AnimatedImageView` wraps `NSImageView` with `animates = true`. Layout priorities on the NSImageView must stay `.defaultLow` on all axes — otherwise `LazyVGrid` triggers layout recursion warnings.

**Keychain:** The Tenor API key is stored under service `com.lavi.GifDropper`, account key `tenorAPIKey`. `Keychain.read/write` are `nonisolated` static methods. The key is entered once in `SettingsView` (gear icon in the popover).

**Tenor API:** `GET https://tenor.googleapis.com/v2/search` with `media_filter=tinygif,gif`. `tinygif` is used for the preview grid (small, fast); `gif` is used for the drag payload (full quality).

## Known non-issues in Xcode logs

These appear at runtime and are harmless — do not try to fix them:
- `fopen failed for data file: errno = 2` — system SQLite
- `ViewBridge to RemoteViewService Terminated` — SwiftUI/AppKit bridge, benign
- `cannot open file … /private/var/db/DetachedSignatures` — codesign cache miss in dev builds
