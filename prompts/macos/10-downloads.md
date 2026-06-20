# Prompt 10 — Downloads

## Context
The browser handles navigation, tabs, Spaces, history, and favorites. A real daily-driver must handle
**file downloads**. We add download handling via `WKDownload` and a downloads UI.

## Goal
Intercept downloads (links and responses the engine can't render), save them to the user's Downloads
folder, track progress, and present a downloads popover with progress, reveal-in-Finder, open, and
clear. Downloads persist in the list across launches (metadata, not re-downloading).

## Architecture / constraints
- Download handling in **`BrowserCore`**: implement `WKDownloadDelegate` and the
  `WKNavigationDelegate` hooks (`decidePolicyFor navigationResponse` / `download` becomes a download)
  to route to a `DownloadManager` (`@Observable`). Track per-download: `id`, `filename`,
  `destinationURL`, `bytesReceived`, `totalBytes`, `state` (in-progress/finished/failed/cancelled).
- Default destination = user's Downloads directory; respect suggested filename; avoid overwriting
  (uniquify). Surface a security-sane prompt only if needed (v1 can auto-save to Downloads).
- Persist download records (SwiftData) so the list survives relaunch (do not resume partials in v1 —
  finished/failed states only after restart).
- UI in **`apps/macos`**: a toolbar downloads button with a popover list; per-row progress bar,
  cancel (in-progress), reveal-in-Finder, open, remove. A subtle indicator when a download is active.

## Tasks
1. Add `DownloadManager` (`@Observable`) + `DownloadRecord` `@Model` to `BrowserCore`; implement
   `WKDownloadDelegate` and wire it from the nav delegate.
2. Implement start → progress (KVO on `WKDownload.progress`) → finish/fail/cancel, saving to Downloads
   with filename uniquification.
3. Persist download records; reload them into the list on launch (state reflects last-known).
4. Build the downloads popover UI with progress, cancel, reveal, open, remove, and clear-all.
5. Add a toolbar button + active indicator; optional shortcut `⌘⇧J` to open the downloads popover.
6. Commit: `feat(core+macos): downloads via WKDownload with progress popover`.

## Acceptance criteria
- [ ] Clicking a downloadable link saves the file to Downloads with visible progress.
- [ ] Cancel works mid-download; reveal-in-Finder and open work for finished files.
- [ ] The downloads list persists across relaunch (no duplicate re-downloads).
- [ ] Filenames don't overwrite existing files.

## Out of scope
No resumable/partial downloads across launches. No custom per-download destination picker (auto-Downloads is fine for v1).
