import Foundation
import Observation
import WebKit

/// Owns an ordered collection of `WebTab`s and tracks which one is active.
///
/// Tabs are referenced by `WebTab.ID` rather than by index or strong reference, so the active
/// selection survives reordering and is unambiguous after inserts/removals. This type is
/// platform-agnostic (it never hardcodes a home URL); the hosting app decides what a new tab loads.
@Observable
@MainActor
public final class TabManager {
  /// The tabs in display order.
  public private(set) var tabs: [WebTab]
  /// The id of the active tab, or `nil` only transiently. There is always at least one tab.
  public private(set) var activeTabID: WebTab.ID?

  /// Tabs the auto-archive pass swept out of the live list (Prompt 11). Held as lightweight
  /// ``ArchivedTab`` records — not live `WebTab`s — so an archived tab's `WKWebView` is freed; restoring
  /// rebuilds a fresh tab. The sidebar surfaces these in an Archived view; persistence round-trips them
  /// as `TabRecord`s flagged `isArchived`.
  public private(set) var archivedTabs: [ArchivedTab] = []

  /// The active tab resolved from `activeTabID`, or `nil` if it cannot be found.
  public var activeTab: WebTab? {
    guard let activeTabID else { return nil }
    return tabs.first { $0.id == activeTabID }
  }

  /// Pinned tabs, in display order. The sidebar renders these in a sticky section above the rest, and
  /// (when Prompt 11 auto-archive lands) the archive pass must skip them — `WebTab.isPinned` is that
  /// exemption signal.
  public var pinnedTabs: [WebTab] { tabs.filter(\.isPinned) }

  /// The non-pinned tabs, in display order — the sidebar's main "Open" section.
  public var unpinnedTabs: [WebTab] { tabs.filter { !$0.isPinned } }

  /// Sink for committed navigations, fanned out to every tab's `onCommit`. The app sets this (via
  /// `SpaceStore`) to record history; assigning it back-fills existing tabs, and `newTab`/`closeTab`
  /// forward it to tabs they create. `@ObservationIgnored` because it's plumbing, not observable state.
  @ObservationIgnored
  public var historyRecorder: ((URL, String) -> Void)? {
    didSet { for tab in tabs { tab.onCommit = historyRecorder } }
  }

  /// Sink for downloads, fanned out to every tab's `onDownloadStart` exactly like `historyRecorder`.
  /// The app sets this (via `SpaceStore`) to hand each `WKDownload` to its `DownloadStore`.
  @ObservationIgnored
  public var onDownloadStart: ((WKDownload) -> Void)? {
    didSet { for tab in tabs { tab.onDownloadStart = onDownloadStart } }
  }

  /// Seeds exactly one blank tab and makes it active. The app loads its home page into it.
  public init() {
    let first = WebTab()
    self.tabs = [first]
    self.activeTabID = first.id
  }

  /// Rebuilds a manager from restored tabs (session restore). `tabs` must be non-empty to uphold the
  /// "always at least one tab" invariant; `activeTabID` falls back to the first tab if it doesn't
  /// match any tab. The caller (persistence layer) supplies tabs in display order, plus any previously
  /// archived tabs to restore the Archived view.
  public init(tabs: [WebTab], activeTabID: WebTab.ID?, archivedTabs: [ArchivedTab] = []) {
    precondition(!tabs.isEmpty, "TabManager requires at least one tab")
    self.tabs = tabs
    self.activeTabID = tabs.contains { $0.id == activeTabID } ? activeTabID : tabs[0].id
    self.archivedTabs = archivedTabs
  }

  /// Appends a fresh tab, makes it active, and loads `url` into it if provided.
  @discardableResult
  public func newTab(url: URL? = nil) -> WebTab {
    let tab = WebTab()
    tab.onCommit = historyRecorder
    tab.onDownloadStart = onDownloadStart
    tabs.append(tab)
    activeTabID = tab.id
    if let url { tab.load(url) }
    return tab
  }

  /// Makes the tab with `id` active, if it exists, and stamps it accessed so its `lastAccessed`
  /// reflects the selection (this is what keeps a just-viewed tab out of the auto-archive pass).
  public func select(_ id: WebTab.ID) {
    guard let tab = tabs.first(where: { $0.id == id }) else { return }
    activeTabID = id
    tab.markAccessed()
  }

  /// Closes the tab with `id`.
  ///
  /// If the closed tab was active, selects the tab that shifts into the freed slot (the right
  /// neighbor), falling back to the new last tab when the rightmost tab is closed. If this empties
  /// the collection, a fresh blank tab is created and made active so a window is never tab-less.
  public func closeTab(_ id: WebTab.ID) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    let wasActive = activeTabID == id
    tabs.remove(at: index)

    if tabs.isEmpty {
      let fresh = WebTab()
      fresh.onCommit = historyRecorder
      fresh.onDownloadStart = onDownloadStart
      tabs = [fresh]
      activeTabID = fresh.id
      return
    }

    if wasActive {
      let neighbor = tabs[min(index, tabs.count - 1)]
      activeTabID = neighbor.id
    }
  }

  /// Moves the tab at `from` to `to` (remove-then-insert semantics, both clamped to valid ranges).
  /// The active selection is preserved by identity, independent of index.
  public func move(from: Int, to: Int) {
    guard tabs.indices.contains(from) else { return }
    let tab = tabs.remove(at: from)
    let destination = min(max(to, 0), tabs.count)
    tabs.insert(tab, at: destination)
  }

  /// Toggles the pinned state of the tab with `id`. Pinning moves it into the sidebar's pinned section
  /// (rendered via ``pinnedTabs``); the flag persists through `SessionPersistence`'s tab reconcile.
  public func togglePin(_ id: WebTab.ID) {
    guard let tab = tabs.first(where: { $0.id == id }) else { return }
    tab.isPinned.toggle()
  }

  // MARK: - Auto-archive

  /// Sweeps stale tabs out of the live list into ``archivedTabs`` and returns the ones archived.
  ///
  /// A tab is archived when it is **not pinned**, **not the active tab**, and has gone untouched longer
  /// than `threshold` (`now - lastAccessed > threshold`, strict — a tab exactly at the boundary stays).
  /// `now` is injected so the decision is deterministic and unit-testable. Archiving removes the
  /// `WebTab` from `tabs`, which frees its `WKWebView`; the saved url/title/lastAccessed live on as an
  /// ``ArchivedTab``. The active tab is never eligible, so the "always ≥1 live tab" invariant holds.
  /// Mutates nothing when nothing is stale, so a periodic caller won't churn the autosaver.
  @discardableResult
  public func archiveStaleTabs(now: Date = Date(), threshold: TimeInterval) -> [ArchivedTab] {
    let staleIDs = tabs.compactMap { tab -> WebTab.ID? in
      guard !tab.isPinned,
            tab.id != activeTabID,
            now.timeIntervalSince(tab.lastAccessed) > threshold else { return nil }
      return tab.id
    }
    guard !staleIDs.isEmpty else { return [] }

    var archived: [ArchivedTab] = []
    for id in staleIDs {
      guard let tab = tabs.first(where: { $0.id == id }) else { continue }
      archived.append(ArchivedTab(id: tab.id, url: tab.url, title: tab.title, lastAccessed: tab.lastAccessed))
    }
    tabs.removeAll { staleIDs.contains($0.id) }
    archivedTabs.append(contentsOf: archived)
    return archived
  }

  /// Restores an archived tab back into the live list: rebuilds a fresh `WebTab` from the record (which
  /// reloads its page), wires it to the history/download sinks, appends it, and makes it active. Returns
  /// the new tab, or `nil` if no archived tab has `id`.
  @discardableResult
  public func restoreArchived(_ id: ArchivedTab.ID) -> WebTab? {
    guard let index = archivedTabs.firstIndex(where: { $0.id == id }) else { return nil }
    let record = archivedTabs.remove(at: index)
    let tab = WebTab(id: record.id, url: record.url, title: record.title, lastAccessed: Date())
    tab.onCommit = historyRecorder
    tab.onDownloadStart = onDownloadStart
    tabs.append(tab)
    activeTabID = tab.id
    return tab
  }

  /// Permanently discards the archived tab with `id` (the Archived view's Delete action).
  public func deleteArchived(_ id: ArchivedTab.ID) {
    archivedTabs.removeAll { $0.id == id }
  }

  /// Reorders within the pinned section. `from`/`to` are indices into ``pinnedTabs`` (the SidebarView
  /// `.onMove` already applies the insert-before→remove-then-insert adjustment); this maps them to the
  /// backing `tabs` array, leaving the unpinned tabs in place.
  public func movePinned(from: Int, to: Int) {
    moveWithinGroup(pinned: true, from: from, to: to)
  }

  /// Reorders within the unpinned ("Open") section. See ``movePinned(from:to:)`` for the index mapping.
  public func moveUnpinned(from: Int, to: Int) {
    moveWithinGroup(pinned: false, from: from, to: to)
  }

  /// Moves a tab within one section (pinned or unpinned) by translating section-relative indices to
  /// global `tabs` indices, so the other section's tabs keep their positions.
  private func moveWithinGroup(pinned: Bool, from: Int, to: Int) {
    let groupIndices = tabs.indices.filter { tabs[$0].isPinned == pinned }
    guard groupIndices.indices.contains(from) else { return }

    let tab = tabs.remove(at: groupIndices[from])
    // Recompute the group against the shortened array; `to` indexes into that shortened group.
    let remaining = tabs.indices.filter { tabs[$0].isPinned == pinned }
    let clamped = min(max(to, 0), remaining.count)
    let destination = clamped == remaining.count
      ? (remaining.last.map { $0 + 1 } ?? tabs.count)
      : remaining[clamped]
    tabs.insert(tab, at: destination)
  }

  /// Activates the next tab in order, wrapping around to the first.
  public func selectNext() {
    cycle(by: 1)
  }

  /// Activates the previous tab in order, wrapping around to the last.
  public func selectPrevious() {
    cycle(by: -1)
  }

  private func cycle(by offset: Int) {
    guard !tabs.isEmpty,
          let activeTabID,
          let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
    let next = (index + offset + tabs.count) % tabs.count
    self.activeTabID = tabs[next].id
  }
}
