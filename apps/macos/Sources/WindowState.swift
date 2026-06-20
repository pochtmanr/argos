import SwiftUI
import BrowserCore

/// Per-window state for a single browser window. Created once per window by `BrowserWindowView` and
/// kept for the window's lifetime.
///
/// ## Multi-window ownership model
/// Shared app state (the `SpaceStore` and its tabs, plus `HistoryStore`/`FavoritesStore`/
/// `DownloadStore` and the single `ModelContainer`) is injected into every window. Only *selection*
/// and *presentation* are window-local and live here.
///
/// Because each `WebTab` owns exactly one `WKWebView`, and that view can be mounted in only one
/// place, a **Space's live tabs are owned by exactly one window at a time** (an exclusive *claim*,
/// tracked in `SpaceStore.claims`). Two windows therefore always show different Spaces — no
/// `WKWebView` is ever mounted twice. Active-*tab* selection stays on each Space's `TabManager`
/// (no per-window duplication needed): since only one window ever displays a given Space, there is
/// no contention over its active tab.
///
/// Switching this window to a Space already shown elsewhere does **not** steal it — instead the app
/// focuses the window that owns it (see `switchTo(_:in:focus:)`).
@Observable
@MainActor
final class WindowState: Identifiable {
  typealias ID = UUID

  /// The right-side inspector panels. Exactly one (or none) is open per window.
  enum RightPanel: Hashable {
    /// Per-space proxy settings (paste a SOCKS5/HTTP proxy).
    case proxy
    /// AI assistant (UI scaffold for now).
    case ai
  }

  /// Stable window identity: the `WindowGroup` presentation value and the key under which this
  /// window claims a Space in `SpaceStore`.
  let id: ID

  /// The Space this window currently displays. Resolved against the shared `SpaceStore`.
  var activeSpaceID: Space.ID?

  /// Sidebar show/hide, local to this window (⌥⌘S). Previously `BrowserWindowView`'s `@State`.
  var columnVisibility: NavigationSplitViewVisibility = .all

  /// The open right-side panel (proxy or AI), or `nil` when none is shown. Window-local UI state.
  var rightPanel: RightPanel?

  /// Drives the Spaces switcher's "New Space" sheet for *this* window. Set `true` by the sidebar's `+`
  /// button and the `⌘⇧E` menu command so both share one creation flow; the sheet binds to it and
  /// resets it to `false` on dismiss. Window-local so the dialog only appears in the focused window.
  var wantsNewSpaceSheet = false

  /// Toggles a right panel: opening it if closed, switching to it if the other was open, or closing
  /// it if it was already the open one. Drives the two top-right toolbar buttons.
  func toggleRightPanel(_ panel: RightPanel) {
    rightPanel = (rightPanel == panel) ? nil : panel
  }

  /// Per-window presentation controllers — each window opens its own command bar / history sheet /
  /// downloads popover, so ⌘L/⌘Y/⌘⇧J affect only the focused window.
  let commandBar = CommandBarController()
  let history = HistoryWindowController()
  let downloads = DownloadsController()

  init(id: ID = UUID()) {
    self.id = id
  }

  /// The Space this window displays, resolved from the shared store (`nil` if it's been deleted).
  func activeSpace(in store: SpaceStore) -> Space? {
    guard let activeSpaceID else { return nil }
    return store.spaces.first { $0.id == activeSpaceID }
  }

  /// Picks and claims the Space this window should show, used on first appear and to recover when
  /// this window's Space is deleted. Keeps the current `activeSpaceID` if it's still valid and not
  /// taken by another window; otherwise claims the first unclaimed Space; otherwise creates a fresh
  /// one. Idempotent, so it's safe to call repeatedly.
  func claimInitialSpace(in store: SpaceStore, homeURL: URL) {
    if let current = activeSpaceID,
       store.spaces.contains(where: { $0.id == current }),
       store.windowDisplaying(current).map({ $0 == id }) ?? true {
      adopt(current, in: store)
      return
    }

    // Honor the session-restore hint if it's still free, so the first window opens on the Space the
    // user left active last session rather than always grabbing the first one.
    if let hint = store.activeSpaceID,
       store.spaces.contains(where: { $0.id == hint }),
       store.windowDisplaying(hint) == nil {
      adopt(hint, in: store)
      return
    }

    let target = store.firstUnclaimedSpace() ?? store.newSpaceWithHome(homeURL)
    adopt(target.id, in: store)
  }

  /// Switches this window to `spaceID`. If another window already displays it, calls `focus` with
  /// that window's id (so the app can bring it forward) and leaves this window unchanged. Otherwise
  /// releases this window's current claim and adopts the new Space.
  func switchTo(_ spaceID: Space.ID, in store: SpaceStore, focus: (WindowState.ID) -> Void) {
    if let owner = store.windowDisplaying(spaceID), owner != id {
      focus(owner)
      return
    }
    adopt(spaceID, in: store)
  }

  /// Drops this window's claim, freeing its Space for another window. Called when the window closes.
  func release(in store: SpaceStore) {
    store.releaseClaims(for: id)
  }

  /// Claims `spaceID` for this window and points the window (and the persisted restore hint) at it.
  private func adopt(_ spaceID: Space.ID, in store: SpaceStore) {
    store.claim(spaceID, for: id)
    activeSpaceID = spaceID
    store.switchTo(spaceID) // updates the session-restore hint (`activeSpaceID`)
  }
}
