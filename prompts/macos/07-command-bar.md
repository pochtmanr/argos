# Prompt 07 — Command Bar (⌘L)

## Context
The browser persists Spaces and tabs (Prompt 06). Power users want to drive everything from the
keyboard. We add an Arc/Spotlight-style **command bar** overlay triggered by `⌘L` (and `⌘T` for a new
tab into it): type to navigate, search, or jump to an already-open tab.

## Goal
A floating, centered command-bar overlay that, as you type, mixes results from: (1) navigate to URL /
search (via `URLBarParser`), (2) switch to an open tab matching the query, and (3) (placeholder for
history suggestions, wired fully in Prompt 08). Enter acts on the highlighted result; arrows move
selection; Escape dismisses.

## Architecture / constraints
- Reuse **`URLBarParser`** (Prompt 02) for the URL-vs-search decision.
- Suggestion sourcing logic (rank open tabs by title/URL match) goes in **`BrowserCore`** as a pure,
  testable function `func suggestions(for query:, openTabs:, history:) -> [Suggestion]` (history
  param can be empty now; Prompt 08 fills it).
- Overlay UI in **`apps/macos`**: a translucent panel centered over the content, text field
  auto-focused, a results list with keyboard navigation. It should feel instant.
- `⌘L` focuses the command bar pre-filled with the current URL (selected). `⌘T` opens it empty for a
  new tab. Escape closes without changing anything.

## Tasks
1. Add the `Suggestion` type + `suggestions(for:openTabs:history:)` ranking function to `BrowserCore`
   with unit tests (URL action always present; open-tab matches ranked by relevance).
2. Build `CommandBarView` overlay in `apps/macos`: auto-focused field, results list, full keyboard
   control (up/down to move, Return to act, Esc to close, Tab to accept top suggestion).
3. Wire `⌘L` (prefill current URL, selected) and `⌘T` (empty, creates a new tab on submit).
4. Actions: URL/search → load in current or new tab (per how it was opened); open-tab match → select
   that tab; (history suggestions show but are empty until Prompt 08).
5. Make the overlay dismiss on Esc, on click-outside, and after acting.
6. Commit: `feat(macos): ⌘L command bar with URL/search/open-tab switching`.

## Acceptance criteria
- [ ] `⌘L` opens the bar with the current URL selected; typing replaces it.
- [ ] Typing a query lists matching open tabs; Enter on one switches to it.
- [ ] Typing a URL/phrase and pressing Enter navigates/searches.
- [ ] Arrow keys move selection; Esc/click-outside dismiss; the bar feels instant.
- [ ] `suggestions(...)` unit tests pass.

## Out of scope
History-backed suggestions are stubbed until Prompt 08. No command palette of app *actions* (that's
the deferred ambitious-v1 `⌘K` feature).
