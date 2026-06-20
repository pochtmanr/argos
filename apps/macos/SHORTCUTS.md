# Keyboard shortcuts

The complete keyboard map for the macOS browser (v1). Every shortcut below is also discoverable in
the menu bar. Per-window actions (command bar, history, downloads, sidebar, navigation) target the
**focused** window.

## Tabs

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘T` | New Tab | Opens the command bar empty; submitting creates the tab (so `⌘T` then `Esc` adds nothing). |
| `⌘W` | Close Tab | |
| `⌘L` | Open Location… | Opens the command bar pre-filled with the current URL (selected) to navigate, search, or jump to an open tab. |
| `⌘D` | Add to Favorites | Toggles the active page in the current Space's favorites. |
| `⌃⌘P` | Toggle Pin | Pins/unpins the active tab. `⌃⌘` avoids `⌘P` (Print). |
| `⌘⇧]` | Show Next Tab | |
| `⌘⇧[` | Show Previous Tab | |

## View & navigation

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌥⌘S` | Toggle Sidebar | `⌥⌘` avoids the system Toggle-Sidebar item's `⌃⌘S`. Mirrored by the toolbar's sidebar button. |
| `⌘R` | Reload Page | Stops the load instead while a page is loading. |
| `⌘[` | Back | Greyed out at the start of history. |
| `⌘]` | Forward | Greyed out at the end of history. |

## Spaces

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘⇧E` | New Space | |
| `⌘1` … `⌘9` | Switch to Space N | Greyed out for Spaces that don't exist yet. **`⌘`, not `⌃`** — `⌃1…⌃9` is intercepted by macOS Mission Control ("Switch to Desktop N"), so the app uses `⌘` to stay reachable. Switching to a Space already open in another window focuses that window instead of stealing it. |

## Windows

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘N` | New Window | Each window claims its own Space (first unclaimed, else a new one). |

## Panels

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘Y` | Show History | Searchable list of visited pages, grouped by day. |
| `⌘⇧J` | Show Downloads | Toggles the downloads popover (progress, reveal, open, cancel, clear). |

## App

| Shortcut | Action | Notes |
|----------|--------|-------|
| `⌘,` | Settings… | Default search engine, new-tab/home page, restore-on-launch, sidebar width, archive threshold. |
| `⌘Q` | Quit | Flushes the session autosave on the way out. |

## Inside the command bar (`⌘L` / `⌘T`)

| Key | Action |
|-----|--------|
| `Return` | Act on the highlighted result. |
| `↑` / `↓` | Move the highlight. |
| `Tab` | Accept the top result. |
| `Esc` | Dismiss (also click outside). |

## Inside the address bar

| Key | Action |
|-----|--------|
| `Return` | Navigate to / search the typed text (using the configured search engine). |
| `Esc` | Restore the current URL and drop focus. |
