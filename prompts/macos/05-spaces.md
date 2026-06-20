# Prompt 05 — Spaces (the hero feature)

## Context
There's a vertical tab sidebar over a `TabManager` (Prompt 04). Now we add **Spaces** — the signature
feature. A Space is a named, colored container of tabs (e.g. Work, Personal, a project). The sidebar
shows the current Space's tabs and a switcher to move between Spaces. This is the product's identity;
make it feel good.

## Goal
Introduce a `Space` model and a `SpaceStore` that owns multiple Spaces, each with its own ordered tab
list and active tab. The sidebar shows the active Space's tabs plus a Spaces switcher (create, rename,
recolor, delete, reorder). Switching Spaces swaps the visible tab set; tabs in other Spaces stay alive
or are cleanly suspended (your call — document it).

## Architecture / constraints
- `Space` + `SpaceStore` in **`BrowserCore`**. `Space`: `id`, `name`, `colorHex` (or symbol/emoji),
  `icon`, ordered `tabs`, `activeTabID`. `SpaceStore` (`@Observable`): `spaces: [Space]`,
  `activeSpace`, `newSpace`, `rename`, `recolor`, `deleteSpace`, `moveSpace`, `switchTo`.
- Reconcile with `TabManager`: cleanest is **`TabManager` scoped to the active Space** (the active
  Space owns its tabs), or `SpaceStore` becomes the top-level owner and `TabManager` operates within
  it. Pick one, keep ownership unambiguous, and document it in a short comment.
- Keeping web views alive across Space switches is ideal for instant switching; if memory is a
  concern, suspend non-active Spaces' web views and reload on return. Document the chosen behavior.
- Switcher UI in **`apps/macos`**, top or bottom of the sidebar: per-Space chip/row with color + name;
  `⌃1…⌃9` to jump to Space N; `⌘⇧E` or similar to create.

## Tasks
1. Add `Space` and `SpaceStore` to `BrowserCore` with the operations above + unit tests
   (create/switch/delete-active-space behavior, moving tabs is fine to defer).
2. Refactor tab ownership so each Space has its own tabs and active tab. The detail pane renders the
   active Space's active tab.
3. Build the **Spaces switcher** in the sidebar: colored chips/rows, current Space highlighted, create
   "+", context menu for rename/recolor/delete.
4. Add keyboard shortcuts: `⌃1…⌃9` switch Space, a shortcut to create a Space, and keep `⌘T`/`⌘W`
   scoped to the active Space.
5. Seed a default Space on first run so the app is never empty.
6. Commit: `feat(core+macos): Spaces — named/colored tab containers with switcher`.

## Acceptance criteria
- [ ] Multiple Spaces exist; switching shows that Space's own tabs and active tab.
- [ ] Create / rename / recolor / delete a Space works; deleting the active Space falls back sensibly.
- [ ] `⌃1…⌃9` jumps between Spaces; `⌘T`/`⌘W` affect only the active Space.
- [ ] `SpaceStore` unit tests pass; ownership of tabs is unambiguous and documented.

## Out of scope
No persistence yet (Prompt 06 — Spaces/tabs will be saved & restored). No per-Space profiles/data
isolation yet (deferred). No drag-tab-between-Spaces required (nice-to-have, optional).
