# Prompt 11 — Tab Auto-Archive

## Context
The persisted tab record already carries `lastAccessed` (Prompt 06) and pinned tabs are exempt
(Prompt 09). Now we complete the Arc-style identity: **tabs that go stale automatically archive**, so
the sidebar stays clean, with an Archived view to bring them back.

## Goal
Automatically archive tabs that haven't been accessed within a configurable threshold (default e.g.
12h or 24h), removing them from the active sidebar list while keeping a restorable record. Provide an
Archived view to search/restore/delete archived tabs. Pinned and currently-active tabs never archive.

## Architecture / constraints
- Logic in **`BrowserCore`**: extend `TabManager`/`SpaceStore` with an archive pass. `lastAccessed`
  updates whenever a tab is selected or navigated. An `archiveStaleTabs(now:threshold:)` function
  (pure/testable) decides which tabs to archive: not pinned, not active, `now - lastAccessed > threshold`.
- Archived tabs persist as records with an `isArchived` flag (or moved to an archive store); they free
  their live `WKWebView` (reload on restore). The threshold is a user setting (default sensible).
- Run the archive pass on a timer and on app foreground/launch. Archiving is per-Space.
- UI in **`apps/macos`**: an "Archived" section/view (per Space or global — document) listing archived
  tabs with restore + delete + search; restoring re-creates a live tab in its Space.

## Tasks
1. Add `archiveStaleTabs(now:threshold:)` to `BrowserCore` with unit tests (respects pinned/active,
   threshold boundary, per-Space scoping). Ensure `lastAccessed` updates on select/navigate.
2. Persist `isArchived`; free archived tabs' web views; restore re-creates a live tab from the record.
3. Schedule the archive pass (timer + on launch/foreground). Make the threshold a stored setting.
4. Build the Archived view: list/search archived tabs, restore, delete; show a small count badge.
5. Confirm pinned and active tabs never archive, and restore preserves URL/title.
6. Commit: `feat(core+macos): automatic tab archiving with restore`.

## Acceptance criteria
- [ ] Idle non-pinned tabs archive after the threshold and leave the active sidebar.
- [ ] The active tab and pinned tabs never archive.
- [ ] Archived tabs are searchable and restorable to their Space; restore reloads the page.
- [ ] Threshold is configurable; `archiveStaleTabs` unit tests pass.

## Out of scope
No ML "smart" archiving. No archive sync. Threshold UI can live in the Prompt 13 Settings scene
(a default + a temporary control here is fine).
