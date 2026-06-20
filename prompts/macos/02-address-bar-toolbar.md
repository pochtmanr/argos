# Prompt 02 — Address Bar & Toolbar

## Context
A single `WebTab` renders a hardcoded page with observable nav state (Prompt 01). Now make it a
controllable browser: an address bar and navigation buttons driven by the same `WebTab` state. Replace
the temporary top strip from Prompt 01.

## Goal
A working top toolbar: editable address field, back / forward / reload (or stop while loading)
buttons, a determinate progress indicator, and a `URLBarParser` that decides whether typed text is a
URL to visit or a query to search.

## Architecture / constraints
- `URLBarParser` goes in **`BrowserCore`** (pure, testable, reused by iOS + the command bar later).
  Rules: looks-like-a-domain or has a scheme → treat as URL (add `https://` if missing); otherwise
  → search via a configurable engine (default `https://www.google.com/search?q=`). Handle
  `localhost`, IPs, and `about:`/`file:` reasonably.
- Toolbar UI goes in **`apps/macos`** as a SwiftUI view bound to the active `WebTab`.
- Back/forward buttons enabled from `canGoBack`/`canGoForward`. The reload button becomes a **stop**
  button while `isLoading`. Progress bar bound to `estimatedProgress`, hidden when not loading.
- The address field shows the current `url` when not focused, and the user's text while editing;
  pressing Return navigates (`load` or search) via `URLBarParser`.

## Tasks
1. Add `URLBarParser` to `BrowserCore` with `func resolve(_ input: String) -> URL` (and a small enum
   describing url-vs-search if useful). Include unit tests covering: bare domain, full URL, missing
   scheme, search phrase, localhost, IP.
2. Build `ToolbarView` in `apps/macos`: back, forward, reload/stop, the address `TextField`, and a
   reload spinner/progress. Bind everything to the active `WebTab`.
3. Replace the Prompt 01 temporary strip with `ToolbarView`. Address field commits on Return.
4. Show favicon + title affordance in/near the address bar (favicon can be a placeholder system image
   for now; real favicons are fine if trivial via the page).
5. Make the address field focusable and select-all on focus (Arc-like). Escape resets to current URL.
6. Commit: `feat(macos): address bar + nav toolbar with URL/search parsing`.

## Acceptance criteria
- [ ] Typing a domain navigates there; typing a phrase runs a search.
- [ ] Back/forward enable/disable correctly; reload toggles to stop during load.
- [ ] Progress bar animates on navigation and hides when idle.
- [ ] `URLBarParser` unit tests pass.
- [ ] Address field shows current URL when unfocused, editable text when focused.

## Out of scope
Still a single tab. No tab bar/sidebar yet (Prompt 03+). No history suggestions yet (Prompt 07/08).
