# Prompt 13 — Window Chrome & Polish (v1 finish line)

## Context
All functional pieces of the daily-driver core exist (Prompts 00–12). This final v1 prompt makes it
**look and feel like a crafted Mac app**: custom window chrome (Arc-style full-height sidebar), a
Settings scene, a complete keyboard-shortcut map, and the app menu/About/icon. After this, v1 is
shippable as a personal daily driver.

## Goal
Polish the shell: a transparent/full-height-sidebar titlebar with properly inset traffic lights, a
Settings/Preferences window (default search engine, archive threshold, new-tab behavior, restore
behavior), a documented and complete keyboard-shortcut set wired into the menu bar, and basic
app identity (icon, About, app name).

## Architecture / constraints
- Window chrome in **`apps/macos`**: `titlebarAppearsTransparent`, full-size content view, hide the
  title, let the sidebar run full height under the traffic lights with correct inset (NSWindow
  configuration via an `NSViewRepresentable`/`NSWindowDelegate` bridge or `WindowGroup` styling).
  Keep it clean on resize and fullscreen.
- **Settings** via the SwiftUI `Settings` scene: surface existing options — default search engine
  (used by `URLBarParser`), archive threshold (Prompt 11), restore-on-launch toggle, new-tab page/URL,
  sidebar default width. Persist via `@AppStorage`/SwiftData as appropriate.
- **Menu bar + shortcuts**: implement `Commands` covering everything built — `⌘T/⌘W/⌘N`, `⌘L` command
  bar, `⌘R` reload, `⌘[`/`⌘]` back/forward, `⌃1…⌃9` Spaces, `⌘D` favorite, `⌘Y` history, `⌘⇧J`
  downloads, sidebar toggle, `⌘,` settings, `⌘Q`. Ensure each maps to the right action.
- App identity: app icon set, `About` panel, product name, version.

## Tasks
1. Implement the custom titlebar / full-height sidebar with correct traffic-light inset; verify resize
   and fullscreen behavior.
2. Build the `Settings` scene with the options above, wired to the real stores/parsers (changing the
   search engine actually changes `URLBarParser`; changing the threshold changes archiving).
3. Implement the full `Commands` menu so every shortcut is discoverable in the menu bar and works.
4. Add app icon, About panel, and product naming/versioning.
5. Write `apps/macos/SHORTCUTS.md` documenting the complete keyboard map; link it from the README.
6. Do a final pass: no build warnings, no console errors on normal use, smooth window behavior.
7. Commit: `feat(macos): custom window chrome, Settings, full shortcut map — v1 daily-driver`.

## Acceptance criteria
- [ ] Sidebar runs full height with correctly inset traffic lights; clean on resize/fullscreen.
- [ ] Settings changes (search engine, archive threshold, restore, new-tab) take effect live and persist.
- [ ] Every built feature has a working, menu-discoverable keyboard shortcut; `SHORTCUTS.md` matches.
- [ ] App has an icon, About panel, and product name; builds with no warnings.
- [ ] The app is usable as a daily driver end-to-end (open, browse, Spaces, restore, archive, downloads).

## Out of scope
Everything in the deferred list (split view, extensions, profiles, accounts/sync, AI). Those are
post-v1 specs. This prompt closes out **v1 daily-driver core**.
