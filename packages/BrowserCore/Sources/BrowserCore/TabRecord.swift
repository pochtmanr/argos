import Foundation
import SwiftData

/// The persisted (at-rest) shape of a `WebTab`. Holds only the data needed to recreate a tab on
/// launch — never the live `WKWebView` or transient load state (progress, isLoading). The persistence
/// layer maps `TabRecord ↔ WebTab` on load/save.
///
/// `isPinned` and `lastAccessed` are persisted now even though their UIs arrive later — they back
/// pinned tabs (Prompt 09) and auto-archive (Prompt 11). Every property has a default so SwiftData's
/// automatic lightweight migration can extend the schema without wiping the store.
@Model
public final class TabRecord {
  /// Matches `WebTab.id`. Unique so save can upsert by id.
  @Attribute(.unique) public var id: UUID
  /// The page URL to reload on restore. Optional for a never-navigated blank tab.
  public var url: URL?
  /// Last known page title, shown in the sidebar before a deferred tab loads.
  public var title: String
  /// Position within its space's tab list; the save path writes the array index here.
  public var order: Int
  /// Whether the user pinned this tab (Prompt 09).
  public var isPinned: Bool = false
  /// When this tab was last active (Prompt 11 auto-archive).
  public var lastAccessed: Date = Date.distantPast
  /// Whether the auto-archive pass swept this tab out of the live list (Prompt 11). Archived records
  /// restore as lightweight `ArchivedTab`s (no live `WKWebView`) rather than as open tabs.
  public var isArchived: Bool = false
  /// Owning space (inverse of `SpaceRecord.tabs`); the persisted space membership.
  public var space: SpaceRecord?

  public init(
    id: UUID,
    url: URL?,
    title: String,
    order: Int,
    isPinned: Bool = false,
    lastAccessed: Date = .distantPast,
    isArchived: Bool = false
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.order = order
    self.isPinned = isPinned
    self.lastAccessed = lastAccessed
    self.isArchived = isArchived
  }
}
