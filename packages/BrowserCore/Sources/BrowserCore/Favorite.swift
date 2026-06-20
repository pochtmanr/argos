import Foundation
import SwiftData

/// A saved site the user pinned for quick access. Persisted flat (no folders/hierarchy in v1) and
/// surfaced as the sidebar's favorites strip and as command-bar suggestions.
///
/// Favorites are per-Space: `spaceID` is the owning ``Space/id``. It is modelled as a plain UUID rather
/// than a SwiftData relationship to keep favorites out of the space↔tab reconcile graph (they live in
/// the same store but are managed directly by `FavoritesStore`, mirroring `HistoryRecord`). `nil` is
/// reserved for a future "global" mode. Every property has a default so SwiftData's lightweight
/// migration can introduce this model without wiping the store.
@Model
public final class Favorite {
  /// Stable identity; unique so a favorite can be removed by id.
  @Attribute(.unique) public var id: UUID
  /// The saved page URL. Always present — favorites are only created from a loaded page or a tab.
  public var url: URL
  /// Display title (falls back to the host in the UI when empty).
  public var title: String
  /// Position within its Space's favorites list; `FavoritesStore` keeps these dense (0…n-1).
  public var order: Int
  /// Owning Space (``Space/id``). `nil` reserved for a future global mode; currently always set.
  public var spaceID: UUID?

  public init(id: UUID = UUID(), url: URL, title: String, order: Int, spaceID: UUID? = nil) {
    self.id = id
    self.url = url
    self.title = title
    self.order = order
    self.spaceID = spaceID
  }
}
