# Prompt 03 — Tab Manager

## Context
The browser drives one `WebTab` through a toolbar (Prompt 02). Now support **multiple** tabs with a
manager that owns them and tracks which is active. No sidebar UI yet — a simple temporary horizontal
tab strip is enough to prove switching; the real vertical sidebar comes in Prompt 04.

## Goal
Introduce a `TabManager` (`@Observable`) that owns an ordered collection of tabs, exposes the active
tab, and supports new/close/select/move. Wire `⌘T` (new tab) and `⌘W` (close tab). The toolbar and
web view follow the active tab. Each tab keeps its own live `WKWebView` and back/forward history.

## Architecture / constraints
- `TabManager` in **`BrowserCore`**: `tabs: [WebTab]`, `activeTab: WebTab?` (or active id),
  `newTab(url:)`, `closeTab(_:)`, `select(_:)`, `move(from:to:)`. Closing the active tab selects a
  sensible neighbor. Closing the last tab opens a fresh blank/new-tab.
- Give `WebTab` a stable `id` (UUID). It already owns its `WKWebView`; switching tabs must **not**
  reload — keep web views alive while their tab exists.
- The content area renders the active tab's `WebView`. Use a stable identity so SwiftUI doesn't tear
  down inactive web views (e.g. keep tabs mounted in a `ZStack` with opacity, or otherwise preserve
  the `WKWebView` instances). Document the approach you choose.
- Inject `TabManager` via SwiftUI `Environment`. The toolbar now binds to `manager.activeTab`.

## Tasks
1. Add `TabManager` to `BrowserCore` with the operations above + unit tests for close/select/move and
   the "close active picks neighbor" / "close last opens new" rules.
2. Replace the single-tab holding in `apps/macos` with a `TabManager` in the environment. Content area
   shows the active tab; toolbar binds to the active tab.
3. Ensure switching tabs preserves each tab's page, scroll, and back/forward state (no reload).
4. Add a **temporary** horizontal tab strip (title + close button + a "+") to switch/create/close —
   clearly marked as throwaway, to be replaced by the sidebar in Prompt 04.
5. Add keyboard commands: `⌘T` new tab, `⌘W` close active tab, `⌘⇧]`/`⌘⇧[` (or `⌃Tab`) to cycle.
6. Commit: `feat(core+macos): TabManager with multi-tab switching and ⌘T/⌘W`.

## Acceptance criteria
- [ ] Multiple tabs open simultaneously; switching is instant and does **not** reload pages.
- [ ] `⌘T`/`⌘W` work; closing the active tab selects a neighbor; closing the last opens a new tab.
- [ ] Each tab retains independent navigation history and scroll position.
- [ ] `TabManager` unit tests pass.

## Out of scope
The horizontal strip is temporary. No vertical sidebar, no Spaces, no persistence yet.
