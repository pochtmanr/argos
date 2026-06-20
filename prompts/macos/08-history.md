# Prompt 08 — History

## Context
The command bar (Prompt 07) is ready for history-backed suggestions, but nothing records browsing
history yet. We add a `HistoryStore` that records visits, a searchable History view, and we feed
history into the command bar's suggestions.

## Goal
Record a `HistoryEntry` on each committed navigation, persist it (SwiftData), expose search/recent
queries, surface results in the `⌘L` command bar, and provide a dedicated History view (list, search,
delete entry, clear range).

## Architecture / constraints
- `HistoryEntry` `@Model` in **`BrowserCore`**: `id`, `url`, `title`, `visitedAt`, `visitCount` (or
  separate visit rows — pick one; document). `HistoryStore` (`@Observable`): `record(url:title:)`,
  `search(_:) -> [HistoryEntry]`, `recent(limit:)`, `delete(_:)`, `clear(since:)`.
- Record on **committed** navigations only (didFinish or didCommit) — not on every redirect/progress
  tick. De-dupe rapid repeats; bump `visitCount`/`visitedAt` for revisits.
- Plug history into the Prompt 07 `suggestions(for:openTabs:history:)` function (now pass real
  history). Rank: exact/open-tab matches, then frequent+recent history, then the raw URL/search action.
- History view UI in **`apps/macos`**: searchable list grouped by day, row = favicon/title/URL/time,
  delete + "clear last hour/today/all".

## Tasks
1. Add `HistoryEntry` `@Model` + `HistoryStore` to `BrowserCore` (+ unit tests for record/search/
   de-dupe/clear).
2. Hook navigation commit in `WebTab`/`TabManager` to call `HistoryStore.record`. Respect a future
   "private" flag if trivial, else note it as deferred.
3. Pass real history into the command bar's `suggestions(...)`; show top history hits as you type.
4. Build the History view (searchable, grouped by day) reachable via menu + a shortcut (`⌘Y`).
5. Implement delete-entry and clear-range; ensure command-bar suggestions reflect deletions.
6. Commit: `feat(core+macos): browsing history with search + command-bar suggestions`.

## Acceptance criteria
- [ ] Visiting pages records history (de-duped, with visit counts/timestamps).
- [ ] `⌘L` shows relevant history suggestions as you type; selecting one navigates.
- [ ] History view lists/searches/groups entries; delete and clear-range work and persist.
- [ ] `HistoryStore` unit tests pass.

## Out of scope
No private/incognito mode build-out (note the hook only). No sync of history (deferred).
