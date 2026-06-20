import Foundation
import Observation
import WebKit

/// Owns an ordered collection of `Space`s and tracks which one is active.
///
/// Mirrors `TabManager`'s design one level up: spaces are referenced by `Space.ID` (not index), so
/// the active selection survives reordering, and there is always at least one space — deleting the
/// last one reseeds a fresh default. Each `Space` owns its own `TabManager`, so switching spaces
/// swaps the entire visible tab set while every space's tabs (and their `WKWebView`s) stay alive in
/// memory; the UI simply mounts only the active space's web views. This type is platform-agnostic;
/// the hosting app decides what a new space's tab loads.
@Observable
@MainActor
public final class SpaceStore {
  /// The spaces in display order.
  public private(set) var spaces: [Space]
  /// The active space used as the **session-restore hint** — the space the first window restores to
  /// on launch (persisted via `SessionPersistence`). With multiple windows the *live* per-window
  /// selection lives in each window's `WindowState`; this is just the last-active hint, not the
  /// source of truth for what any given window displays.
  public private(set) var activeSpaceID: Space.ID?

  // MARK: - Window claims (multi-window exclusive ownership)

  /// Maps each open window (an opaque id supplied by the app layer) to the single Space it currently
  /// displays. This enforces the multi-window ownership model: **a Space's live tabs and their
  /// `WKWebView`s are owned by exactly one window at a time**, so no `WKWebView` is ever mounted in
  /// two windows. A window displays exactly one Space, so re-claiming moves it off its previous one.
  /// Keyed by an opaque `UUID` (not the app's `WindowState` type) so `BrowserCore` stays layer-clean.
  /// Observable so the Spaces switcher can reflect which spaces are taken.
  public private(set) var claims: [UUID: Space.ID] = [:]

  /// The set of spaces currently displayed by some window.
  public var claimedSpaceIDs: Set<Space.ID> { Set(claims.values) }

  /// The window currently displaying `spaceID`, or `nil` if no window has claimed it.
  public func windowDisplaying(_ spaceID: Space.ID) -> UUID? {
    claims.first { $0.value == spaceID }?.key
  }

  /// The first space (in display order) not displayed by any window, or `nil` if all are claimed.
  /// The app uses this to pick which Space a newly opened window shows.
  public func firstUnclaimedSpace() -> Space? {
    let claimed = claimedSpaceIDs
    return spaces.first { !claimed.contains($0.id) }
  }

  /// Records that `windowID` now displays `spaceID`, replacing any space that window previously held
  /// (a window shows exactly one Space at a time).
  public func claim(_ spaceID: Space.ID, for windowID: UUID) {
    claims[windowID] = spaceID
  }

  /// Drops `windowID`'s claim, freeing its Space for another window (called when a window closes).
  public func releaseClaims(for windowID: UUID) {
    claims[windowID] = nil
  }

  /// The active space resolved from `activeSpaceID`, or `nil` if it cannot be found.
  public var activeSpace: Space? {
    guard let activeSpaceID else { return nil }
    return spaces.first { $0.id == activeSpaceID }
  }

  /// App-level sink for committed navigations (history recording). Set once at app root; it fans out
  /// to every space's `TabManager` (which in turn fans out to its tabs), and `newSpace`/`deleteSpace`
  /// forward it to spaces they create, so restored and newly-made tabs all report through one path.
  /// `@ObservationIgnored` because it's plumbing, not observable state.
  @ObservationIgnored
  public var historyRecorder: ((URL, String) -> Void)? {
    didSet { for space in spaces { space.tabManager.historyRecorder = historyRecorder } }
  }

  /// App-level sink for downloads, cascaded to every space's `TabManager` exactly like
  /// `historyRecorder`. Set once at app root; the app points it at its `DownloadStore`.
  /// `@ObservationIgnored` because it's plumbing, not observable state.
  @ObservationIgnored
  public var onDownloadStart: ((WKDownload) -> Void)? {
    didSet { for space in spaces { space.tabManager.onDownloadStart = onDownloadStart } }
  }

  /// Seeds exactly one default space and makes it active. Its `TabManager` seeds one blank tab, so
  /// the app is never empty on first run.
  public init() {
    let first = Self.makeDefaultSpace()
    self.spaces = [first]
    self.activeSpaceID = first.id
  }

  /// Rebuilds a store from restored spaces (session restore). `spaces` must be non-empty to uphold
  /// the "always at least one space" invariant; `activeSpaceID` falls back to the first space if it
  /// doesn't match any space. The caller (persistence layer) supplies spaces in display order.
  public init(spaces: [Space], activeSpaceID: Space.ID?) {
    precondition(!spaces.isEmpty, "SpaceStore requires at least one space")
    self.spaces = spaces
    self.activeSpaceID = spaces.contains { $0.id == activeSpaceID } ? activeSpaceID : spaces[0].id
  }

  /// Appends a fresh space, makes it active, and returns it. The new space starts with its own
  /// seeded blank tab; the hosting app decides what to load into it.
  @discardableResult
  public func newSpace(
    name: String = "New Space",
    colorHex: String = SpaceStore.defaultColorHex,
    icon: String = SpaceStore.defaultIcon
  ) -> Space {
    let space = Space(name: name, colorHex: colorHex, icon: icon)
    space.tabManager.historyRecorder = historyRecorder
    space.tabManager.onDownloadStart = onDownloadStart
    spaces.append(space)
    activeSpaceID = space.id
    return space
  }

  /// Makes the space with `id` active, if it exists.
  public func switchTo(_ id: Space.ID) {
    guard spaces.contains(where: { $0.id == id }) else { return }
    activeSpaceID = id
  }

  /// Renames the space with `id`, if it exists.
  public func rename(_ id: Space.ID, to name: String) {
    space(id)?.name = name
  }

  /// Recolors the space with `id` (hex string), if it exists.
  public func recolor(_ id: Space.ID, to colorHex: String) {
    space(id)?.colorHex = colorHex
  }

  /// Sets the SF Symbol icon for the space with `id`, if it exists.
  public func setIcon(_ id: Space.ID, to icon: String) {
    space(id)?.icon = icon
  }

  /// Deletes the space with `id`.
  ///
  /// If the deleted space was active, selects the space that shifts into the freed slot (the right
  /// neighbor), falling back to the new last space when the rightmost is deleted. If this empties
  /// the collection, a fresh default space is created and made active so the app is never empty —
  /// mirroring `TabManager.closeTab`. Removing the space drops the last strong reference to its
  /// `TabManager`/`WebTab`s, so its web views are released.
  public func deleteSpace(_ id: Space.ID) {
    guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
    let wasActive = activeSpaceID == id
    spaces.remove(at: index)
    // Free any window's claim on the deleted space so it's no longer reported as displayed; the
    // owning window (if any) re-claims another space when it notices its space is gone.
    if let owner = windowDisplaying(id) { claims[owner] = nil }

    if spaces.isEmpty {
      let fresh = Self.makeDefaultSpace()
      fresh.tabManager.historyRecorder = historyRecorder
      fresh.tabManager.onDownloadStart = onDownloadStart
      spaces = [fresh]
      activeSpaceID = fresh.id
      return
    }

    if wasActive {
      let neighbor = spaces[min(index, spaces.count - 1)]
      activeSpaceID = neighbor.id
    }
  }

  /// Moves the space at `from` to `to` (remove-then-insert semantics, both clamped to valid
  /// ranges). The active selection is preserved by identity, independent of index.
  public func moveSpace(from: Int, to: Int) {
    guard spaces.indices.contains(from) else { return }
    let space = spaces.remove(at: from)
    let destination = min(max(to, 0), spaces.count)
    spaces.insert(space, at: destination)
  }

  // MARK: - Auto-archive

  /// Runs the auto-archive pass across every space (archiving is per-Space). Each `TabManager` exempts
  /// its own active tab and any pinned tabs, so switching spaces doesn't make a space's current tab
  /// vanish. `now` is injected for deterministic testing; the threshold comes from `ArchiveSettings`.
  public func archiveStaleTabs(now: Date = Date(), threshold: TimeInterval) {
    for space in spaces {
      space.tabManager.archiveStaleTabs(now: now, threshold: threshold)
    }
  }

  // MARK: - Defaults & helpers

  /// Default accent color for a seeded space.
  public static let defaultColorHex = "#3B82F6"
  /// Default SF Symbol for a seeded space.
  public static let defaultIcon = "square.stack"

  private func space(_ id: Space.ID) -> Space? {
    spaces.first { $0.id == id }
  }

  private static func makeDefaultSpace() -> Space {
    Space(name: "Personal", colorHex: defaultColorHex, icon: defaultIcon)
  }
}
