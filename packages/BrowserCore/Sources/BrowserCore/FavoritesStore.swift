import Foundation
import Observation
import SwiftData

/// Stores and queries the user's favorites. Owns a `ModelContext` (shared with `SessionPersistence` in
/// production via ``SessionPersistence/makeFavoritesStore()``) and keeps an observable `favorites`
/// cache — refreshed after every mutation — so SwiftUI (the sidebar strip and command bar) updates live.
///
/// Favorites are a flat, query-shaped list, so like `HistoryStore` (and unlike the space↔tab graph)
/// this store talks to SwiftData directly instead of going through `SessionPersistence`'s reconcile.
/// All mutations are scoped to a Space (`spaceID`) and keep each Space's `order` values dense, so the
/// strip renders in a stable, drag-reorderable sequence.
@Observable
@MainActor
public final class FavoritesStore {
  /// Every favorite across all Spaces, sorted by `order`. The UI filters by Space via ``all(spaceID:)``.
  public private(set) var favorites: [Favorite] = []

  @ObservationIgnored
  private let context: ModelContext

  /// Holds the container alive for the `inMemory` path, where this store creates and solely owns it.
  /// (In production the context's container is owned by `SessionPersistence`, so this stays `nil`.)
  @ObservationIgnored
  private let ownedContainer: ModelContainer?

  /// Production initializer: use the container's main context (shared with `SessionPersistence`).
  public init(modelContext: ModelContext) {
    self.context = modelContext
    self.ownedContainer = nil
    reload()
  }

  /// Stands up an isolated store for tests and as a persistence-less fallback. Retains the container it
  /// creates so the context isn't left pointing at a deallocated store.
  public init(inMemory: Bool) throws {
    let schema = Schema(SessionPersistence.models)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    let container = try ModelContainer(for: schema, configurations: configuration)
    self.ownedContainer = container
    self.context = container.mainContext
    reload()
  }

  /// Re-reads favorites from the store. Needed when something outside this store mutates the same
  /// container (e.g. the Debug → Reset Store action clears all `Favorite` rows).
  public func refresh() {
    reload()
  }

  // MARK: - Queries

  /// The favorites belonging to `spaceID`, in display order.
  public func all(spaceID: UUID?) -> [Favorite] {
    favorites.filter { $0.spaceID == spaceID }
  }

  /// Whether `url` is already a favorite of `spaceID` (normalized comparison). Drives the ⌘D toggle.
  public func contains(url: URL, in spaceID: UUID?) -> Bool {
    existing(url: url, in: spaceID) != nil
  }

  // MARK: - Mutations

  /// Adds `url` to `spaceID`'s favorites, appended at the end. De-dupes by normalized URL: a repeat add
  /// returns the existing favorite unchanged.
  @discardableResult
  public func add(url: URL, title: String, spaceID: UUID?) -> Favorite {
    if let existing = existing(url: url, in: spaceID) { return existing }
    let order = all(spaceID: spaceID).count
    let favorite = Favorite(url: url, title: title, order: order, spaceID: spaceID)
    context.insert(favorite)
    persist()
    return favorite
  }

  /// Removes `favorite` and compacts the remaining `order`s in its Space so they stay dense.
  public func remove(_ favorite: Favorite) {
    let spaceID = favorite.spaceID
    context.delete(favorite)
    persist()
    reindex(spaceID: spaceID)
    persist()
  }

  /// Reorders within a Space: moves the favorite at `from` to `to` (both section-relative to that
  /// Space's list), remove-then-insert, then rewrites dense `order`s.
  public func move(from: Int, to: Int, in spaceID: UUID?) {
    var inSpace = all(spaceID: spaceID)
    guard inSpace.indices.contains(from) else { return }
    let item = inSpace.remove(at: from)
    let destination = min(max(to, 0), inSpace.count)
    inSpace.insert(item, at: destination)
    for (index, favorite) in inSpace.enumerated() { favorite.order = index }
    persist()
  }

  /// Toggles `url` in `spaceID`'s favorites: removes it if present, otherwise adds it. Backs ⌘D.
  public func toggle(url: URL, title: String, spaceID: UUID?) {
    if let existing = existing(url: url, in: spaceID) {
      remove(existing)
    } else {
      add(url: url, title: title, spaceID: spaceID)
    }
  }

  // MARK: - Internals

  /// The favorite matching `url` (normalized) within `spaceID`, if any.
  private func existing(url: URL, in spaceID: UUID?) -> Favorite? {
    let key = Self.normalize(url)
    return favorites.first { $0.spaceID == spaceID && Self.normalize($0.url) == key }
  }

  /// Rewrites `order` to 0…n-1 for the favorites in `spaceID`, preserving their current sequence.
  private func reindex(spaceID: UUID?) {
    for (index, favorite) in all(spaceID: spaceID).enumerated() { favorite.order = index }
  }

  /// Normalizes a URL for de-dupe: lowercased, trailing slash trimmed, so `https://x.com` and
  /// `https://x.com/` collapse to one favorite.
  private static func normalize(_ url: URL) -> String {
    var string = url.absoluteString.lowercased()
    if string.hasSuffix("/") { string.removeLast() }
    return string
  }

  /// Saves pending changes and refreshes the observable cache.
  private func persist() {
    try? context.save()
    reload()
  }

  private func reload() {
    let descriptor = FetchDescriptor<Favorite>(sortBy: [SortDescriptor(\.order)])
    favorites = (try? context.fetch(descriptor)) ?? []
  }
}
