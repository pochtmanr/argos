# Prompt 09 — Favorites & Pinned Tabs

## Context
History (Prompt 08) and persistence (Prompt 06, which already stores an `isPinned` flag) are in place.
Now add the two "keep this around" affordances power users expect: **pinned tabs** (sticky at the top
of a Space's sidebar) and **favorites** (saved sites for quick access).

## Goal
Let users pin/unpin tabs (pinned tabs sort to a top section of the sidebar, persist, and don't
auto-archive) and save favorites (a persisted list of URLs surfaced in the sidebar and/or command
bar). `⌘D` adds the current page to favorites.

## Architecture / constraints
- Pinned: reuse the existing persisted `isPinned` on the tab record (Prompt 06). Pinned tabs render
  in a separate top section of the sidebar, above normal tabs, within each Space. Pinned tabs are
  excluded from auto-archive (Prompt 11).
- Favorites: `Favorite` `@Model` in **`BrowserCore`** (`id`, `url`, `title`, `order`, optional
  `spaceID` for per-Space favorites — decide global vs per-Space and document). `FavoritesStore`
  (`@Observable`): `add(url:title:)`, `remove(_:)`, `move(...)`, `all()`.
- UI in **`apps/macos`**: pin/unpin via row context menu + a shortcut; favorites shown as a compact
  section (icons) at the top of the sidebar or a dedicated strip. `⌘D` adds current page.
- Favorites also feed the command bar suggestions (extend the Prompt 07/08 ranking to include them).

## Tasks
1. Add `Favorite` `@Model` + `FavoritesStore` to `BrowserCore` (+ unit tests for add/remove/move/de-dupe).
2. Implement pin/unpin on tabs: context-menu action + shortcut; pinned section at top of sidebar;
   ensure pin state persists (already in the record) and excludes the tab from archiving.
3. Build the favorites UI (sidebar section or strip): click to open, context menu to remove/reorder,
   drag-to-reorder.
4. Wire `⌘D` to add the active page to favorites (toggle if already saved).
5. Extend command-bar `suggestions(...)` to include favorites near the top.
6. Commit: `feat(core+macos): pinned tabs + favorites with ⌘D`.

## Acceptance criteria
- [ ] Pinning moves a tab to a top section; it persists across relaunch and is exempt from archiving.
- [ ] `⌘D` adds/removes the current page from favorites; favorites persist and reorder.
- [ ] Favorites appear in the sidebar and in command-bar suggestions.
- [ ] `FavoritesStore` unit tests pass.

## Out of scope
No bookmark folders/hierarchy (flat list is fine for v1). No import/export. No sync.
