# macOS Browser — Build Prompt Sequence

A native **macOS** power-user browser, Arc-style. Hero feature: **Spaces + vertical tabs** in a
sidebar, with tab auto-archive. Engine: **WebKit / WKWebView**. Stack: **Swift + SwiftUI**,
**SwiftData**, macOS 14+ (Sonoma).

This folder is a **sequence of self-contained build prompts** for Claude Code. Paste them in order,
one at a time. Each ends in a state that **builds and runs**, with an observable behavior you can
verify by launching the app. Do not skip ahead — each prompt assumes the previous one landed.

## Why this design

- **WebKit, not Chromium/Electron.** Native, best battery, Apple-blessed — and it's the *only*
  engine shippable on iOS. Building macOS on WebKit makes the engine layer reusable for the future
  iOS app (Mac→iOS roadmap).
- **Shared Swift core.** The engine + domain layer lives in a `BrowserCore` Swift package and is
  platform-conditional (`NSViewRepresentable` on macOS, `UIViewRepresentable` on iOS). The macOS app
  is just the *chrome* around it. ~70-80% of `BrowserCore` is reused verbatim by iOS later.

## Architecture

```
iosbrowser/
├── apps/
│   ├── macos/            ← NEW: macOS app target (SwiftUI chrome only)
│   ├── ios/              ← existing; rebuilt against BrowserCore LATER (not in v1)
│   └── desktop/          ← existing Electron app; UNMAINTAINED (set aside in the pivot)
├── packages/
│   ├── BrowserCore/      ← NEW: Swift Package — engine + models + stores (shared Mac/iOS)
│   └── ...               ← existing TS packages; reference for a future "accounts" milestone
└── prompts/macos/        ← this folder
```

**`BrowserCore` (Swift Package, platform-conditional):**
- Models (SwiftData `@Model`): `Tab`, `Space`, `HistoryEntry`, `Favorite`
- `WebView` — representable wrapping `WKWebView`
- `WebTab` — owns one `WKWebView` + its navigation/UI/download delegates
- `@Observable` stores: `TabManager`, `SpaceStore`, `HistoryStore`, `FavoritesStore`, `DownloadManager`
- `URLBarParser` — URL-vs-search detection

**`apps/macos` (chrome):** `NavigationSplitView` sidebar (Spaces switcher + vertical tab list),
top toolbar (address bar + back/fwd/reload), `⌘L` command bar overlay, custom `NSWindow` titlebar,
Settings scene.

## Conventions (hold across every prompt)

- **Swift + SwiftUI, WebKit, macOS 14 minimum.** No third-party deps unless a prompt says so.
- **Engine/model/store code → `packages/BrowserCore`. Chrome/UI → `apps/macos`.** Keep the split clean.
- State via **`@Observable`** stores injected through SwiftUI `Environment`. Persistence via **SwiftData**.
- **One `WKWebView` per tab.** v1 uses the default `WKWebsiteDataStore` (per-Space profiles are deferred).
- Each prompt must end **building with no warnings** and with a runnable, verifiable behavior.
- Commit after each green phase (`git` is initialized in Prompt 00).

## The sequence (v1 = daily-driver core)

| # | File | Adds |
|---|------|------|
| 00 | `00-project-skeleton.md` | git init, Xcode macOS app, empty `BrowserCore`, blank window |
| 01 | `01-webkit-single-tab.md` | `WebView` + `WebTab`, render one URL, loading progress |
| 02 | `02-address-bar-toolbar.md` | Address bar, back/fwd/reload/stop, URL-vs-search |
| 03 | `03-tab-manager.md` | Multiple tabs, `TabManager`, ⌘T/⌘W |
| 04 | `04-vertical-sidebar.md` | Vertical tab sidebar, reorder, close/new |
| 05 | `05-spaces.md` | **Spaces** — the hero feature |
| 06 | `06-persistence-swiftdata.md` | SwiftData persistence + session restore |
| 07 | `07-command-bar.md` | `⌘L` command bar overlay |
| 08 | `08-history.md` | History recording + search |
| 09 | `09-favorites-pinned.md` | Pinned tabs + favorites |
| 10 | `10-downloads.md` | Downloads via `WKDownload` |
| 11 | `11-auto-archive.md` | Tab auto-archive + restore |
| 12 | `12-multiwindow.md` | Multiple browser windows |
| 13 | `13-multiwindow-chrome.md` | Custom titlebar, Settings, shortcut map, polish |

## Deferred to post-v1 (intentionally NOT built yet)

Split view / tiling · Safari Web Extensions · per-Space **profiles + proxies** (the existing repo's
`profile-engine`/`proxy-engine` become the reference) · **accounts + cloud sync** (existing
Supabase schema + `sync-engine` + `vault`) · AI sidebar. Each is its own future spec.
