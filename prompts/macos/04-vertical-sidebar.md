# Prompt 04 — Vertical Tab Sidebar

## Context
`TabManager` supports multiple tabs with a temporary horizontal strip (Prompt 03). Now we build the
**real** chrome: a left vertical-tab sidebar — the foundation of the Arc-style identity. Spaces come
next (Prompt 05); this prompt establishes the sidebar shell and the vertical tab list within it.

## Goal
Replace the temporary tab strip with a `NavigationSplitView` whose sidebar is a vertical list of the
manager's tabs (favicon + title + close-on-hover), a "new tab" button at the bottom, and
drag-to-reorder. The detail pane is the toolbar + active web view.

## Architecture / constraints
- UI in **`apps/macos`**. No engine changes expected beyond what `TabManager` already exposes
  (`move(from:to:)` from Prompt 03).
- Use `NavigationSplitView` (sidebar + detail). Sidebar width resizable; remember a sensible default.
- Each row: favicon (placeholder ok), title (fallback to host/URL), close button on hover, selected
  state highlighting. Selecting a row calls `manager.select`.
- Drag-to-reorder calls `manager.move(from:to:)`. Keep reorder smooth (SwiftUI `.onMove` or a custom
  drag); persistence isn't required yet (Prompt 06).
- Address toolbar moves into the detail pane's top; the content area fills the rest.

## Tasks
1. Build `SidebarView` (vertical `List`/`LazyVStack` of tab rows) and `TabRow`. Bind to the
   `TabManager` in the environment.
2. Build `BrowserWindowView` using `NavigationSplitView`: `SidebarView` on the left; on the right the
   `ToolbarView` (Prompt 02) above the active tab's `WebView`.
3. Implement row interactions: select, close (hover button + `⌘W`), new tab (button + `⌘T`).
4. Implement drag-to-reorder via `manager.move`. Active selection must follow the moved tab.
5. Add a sidebar show/hide toggle (`⌘⌃S` or the standard `⌥⌘S`) and keep the window usable collapsed.
6. Remove the temporary horizontal strip from Prompt 03 entirely.
7. Commit: `feat(macos): vertical tab sidebar via NavigationSplitView`.

## Acceptance criteria
- [ ] Tabs render as a vertical list in a left sidebar; selecting switches the active tab.
- [ ] Rows show title + favicon placeholder and a hover close button.
- [ ] Drag-to-reorder works and selection stays correct.
- [ ] Sidebar can be hidden/shown; the temporary horizontal strip is gone.

## Out of scope
No Spaces yet (one implicit space). No persistence. No pinned/favorites section (Prompt 09).
