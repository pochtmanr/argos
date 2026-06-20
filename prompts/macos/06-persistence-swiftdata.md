# Prompt 06 — Persistence & Session Restore (SwiftData)

## Context
Spaces and tabs work in memory (Prompt 05) but vanish on quit. A daily-driver browser must remember
your Spaces, tabs, and order across launches. We add **SwiftData** persistence and session restore.

## Goal
Persist Spaces (name, color, icon, order) and their tabs (URL, title, order, pinned flag,
lastAccessed) so relaunching the app restores the full workspace: same Spaces, same tabs, same active
selection. Live `WKWebView`s are recreated from saved URLs on launch.

## Architecture / constraints
- SwiftData models in **`BrowserCore`**: `@Model` `Space` and `@Model` `TabRecord` (persisted shape;
  keep the live `WebTab` separate from the stored `TabRecord` — `WebTab` owns a `WKWebView` and is not
  itself persisted). Map `TabRecord ↔ WebTab` on load/save.
- Persist: Space `id/name/colorHex/icon/order/activeTabID`; Tab `id/url/title/order/isPinned/
  lastAccessed/spaceID`. Establish the `ModelContainer` in the app and inject the `ModelContext`.
- Save on meaningful changes (tab opened/closed/navigated/reordered, Space CRUD, active changes) —
  debounce writes; don't thrash on every progress tick. Restore on launch before showing the window.
- On launch, rebuild `SpaceStore`/`TabManager` from records; lazily create each tab's `WKWebView`
  (optionally defer loading inactive tabs until selected, to speed startup — document if you do).

## Tasks
1. Define SwiftData `@Model`s and a `ModelContainer` in `BrowserCore`; inject context into the app.
2. Add a persistence layer that maps live state ↔ records, with debounced autosave on changes.
3. Implement **restore on launch**: load Spaces+tabs, recreate web views, restore active Space and
   active tab per Space. If no data exists, seed the default Space (from Prompt 05).
4. Persist tab `isPinned` and `lastAccessed` fields now (they power Prompts 09 and 11) even though
   their UIs come later.
5. Handle migration-safe schema (lightweight) so future model changes don't wipe data.
6. Add a quick reset path for development (e.g. a hidden menu item or env flag to clear the store).
7. Commit: `feat(core): SwiftData persistence + full session restore`.

## Acceptance criteria
- [ ] Quit and relaunch restores all Spaces, their tabs, order, and active selections.
- [ ] Pages reload from saved URLs (optionally lazy for inactive tabs).
- [ ] Reordering tabs/Spaces survives relaunch.
- [ ] Writes are debounced (no excessive disk churn while a page loads).
- [ ] First-ever launch seeds the default Space without error.

## Out of scope
History and favorites get their own stores/UIs (Prompts 08, 09) — but you may add their `@Model`s now
if convenient. No cloud sync (deferred).
