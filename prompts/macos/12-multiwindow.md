# Prompt 12 — Multiple Windows

## Context
The browser is a full single-window daily driver (Prompts 00–11). Mac users expect **multiple
windows**. We add support for several browser windows, each with its own active Space and tab,
sharing the same persisted Spaces/history/favorites/downloads.

## Goal
Open multiple browser windows (`⌘N`), each maintaining independent window-local state (which Space is
showing, which tab is active, sidebar visibility), while all windows share the same underlying stores
(Spaces, tabs, history, favorites, downloads) and stay consistent.

## Architecture / constraints
- Separate **window-local state** from **shared app state**. Shared stores (`SpaceStore` data,
  `HistoryStore`, `FavoritesStore`, `DownloadManager`, the SwiftData container) are app-level
  singletons/environment. Per-window state (active Space, active tab, sidebar visibility) is a
  `WindowState` (`@Observable`) created per window.
- Use SwiftUI `WindowGroup` (and/or `openWindow`) so `⌘N` spawns a new browser window with its own
  `WindowState`. Decide tab-sharing semantics: simplest correct model is **tabs belong to Spaces**
  (shared), and each window views a Space — document how two windows viewing the same Space behave
  (recommended: a tab is "active" per window; avoid two windows fighting over one `WKWebView` by
  either scoping live tabs per window or sharing read-only and document the tradeoff).
- Persist/restore open windows is optional in v1 (note it); at minimum restore one window with full
  session (Prompt 06) and allow opening more.

## Tasks
1. Introduce `WindowState` (`@Observable`) for per-window selection; refactor `BrowserWindowView` to
   read window-local state and shared stores from the environment.
2. Make shared stores app-level (single `ModelContainer`, single `HistoryStore`/`FavoritesStore`/
   `DownloadManager`), injected into every window.
3. Wire `⌘N` to open a new browser window with its own `WindowState` (sensible default Space/tab).
4. Resolve and **document** the live-tab/web-view ownership model across windows (avoid one
   `WKWebView` mounted in two windows simultaneously).
5. Ensure history/favorites/downloads update consistently across all open windows.
6. Commit: `feat(macos): multiple browser windows with shared stores`.

## Acceptance criteria
- [ ] `⌘N` opens an independent browser window; closing one doesn't disturb others.
- [ ] Two windows can show different Spaces/tabs simultaneously without web-view conflicts.
- [ ] History, favorites, and downloads stay consistent across windows.
- [ ] The tab/web-view ownership model across windows is documented.

## Out of scope
No tab drag *between* windows required (nice-to-have). Restoring the exact multi-window layout on
relaunch is optional for v1.
