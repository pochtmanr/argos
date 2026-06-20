import Foundation
import Observation

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

  /// The active tab resolved from `activeTabID`, or `nil` if it cannot be found.
  public var activeTab: WebTab? {
    guard let activeTabID else { return nil }
    return tabs.first { $0.id == activeTabID }
  }

  /// Seeds exactly one blank tab and makes it active. The app loads its home page into it.
  public init() {
    let first = WebTab()
    self.tabs = [first]
    self.activeTabID = first.id
  }

  /// Appends a fresh tab, makes it active, and loads `url` into it if provided.
  @discardableResult
  public func newTab(url: URL? = nil) -> WebTab {
    let tab = WebTab()
    tabs.append(tab)
    activeTabID = tab.id
    if let url { tab.load(url) }
    return tab
  }

  /// Makes the tab with `id` active, if it exists.
  public func select(_ id: WebTab.ID) {
    guard tabs.contains(where: { $0.id == id }) else { return }
    activeTabID = id
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
