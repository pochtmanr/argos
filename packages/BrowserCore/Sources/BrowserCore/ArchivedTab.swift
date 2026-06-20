import Foundation

/// The at-rest shape of an auto-archived tab: a lightweight value holding only what the Archived view
/// needs to display it and what `TabManager.restoreArchived(_:)` needs to recreate a live `WebTab`.
///
/// Archiving must *free* a tab's `WKWebView` (a `WebTab` owns one for its whole lifetime), so an
/// archived tab cannot stay a live `WebTab` — it leaves `TabManager.tabs` and becomes one of these.
/// Restore rebuilds a fresh `WebTab` from this record (which reloads the page). Value semantics let the
/// autosaver catch archive/restore/delete just by observing the `archivedTabs` array.
public struct ArchivedTab: Identifiable, Equatable, Sendable {
  /// The id the tab was archived under; reused when restored so it round-trips through persistence.
  public let id: UUID
  /// The page URL to reload on restore. Optional for a never-navigated blank tab.
  public var url: URL?
  /// Last known page title, shown in the Archived view.
  public var title: String
  /// When the tab was last active before it went stale; the Archived view sorts by this (newest first).
  public var lastAccessed: Date

  public init(id: UUID, url: URL?, title: String, lastAccessed: Date) {
    self.id = id
    self.url = url
    self.title = title
    self.lastAccessed = lastAccessed
  }
}
