import Foundation
import SwiftData

/// Owns the SwiftData store and maps the live `SpaceStore` graph ↔ persisted records.
///
/// Runs on the main actor because it reads/writes `Space`/`WebTab`, which are `@MainActor`. The
/// design keeps the live graph (which owns `WKWebView`s and observation state) strictly separate from
/// the at-rest records: `load()` rebuilds the live graph from records, `save(_:)` snapshots it back.
///
/// Restored tabs are created with `deferLoad: true` — they show their saved title/URL immediately but
/// only fetch their page when first activated (via `WebTab.ensureLoaded()`), so launch doesn't kick
/// off every tab's network load at once.
@MainActor
public final class SessionPersistence {
  /// The models that make up the persisted schema, in one place so the container and any future
  /// `VersionedSchema`/`SchemaMigrationPlan` stay in sync.
  public static let models: [any PersistentModel.Type] = [SpaceRecord.self, TabRecord.self, HistoryRecord.self, Favorite.self, DownloadRecord.self]

  /// `UserDefaults` key for the top-level active-space pointer. SwiftData stores each space's active
  /// *tab* (`SpaceRecord.activeTabID`), but "which space is active" is a single app-level value, so
  /// it lives here rather than as a flag duplicated across rows.
  private static let activeSpaceKey = "activeSpaceID"

  private let container: ModelContainer
  private let defaults: UserDefaults
  private var context: ModelContext { container.mainContext }

  /// Builds the store. `inMemory` backs tests with an ephemeral store; production uses the default
  /// on-disk store in Application Support. `defaults` is injectable for tests.
  public init(inMemory: Bool = false, defaults: UserDefaults = .standard) throws {
    let schema = Schema(Self.models)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    self.container = try ModelContainer(for: schema, configurations: configuration)
    self.defaults = defaults
  }

  /// Vends a `HistoryStore` backed by this same container, so browsing history lives in the one store
  /// file alongside spaces/tabs. History is otherwise independent of the space↔tab graph: the store
  /// reads/writes its own `HistoryRecord` rows directly and is not part of `save(_:)`/`load()`.
  public func makeHistoryStore() -> HistoryStore {
    HistoryStore(modelContext: container.mainContext)
  }

  /// Vends a `FavoritesStore` backed by this same container, so favorites live in the one store file
  /// alongside spaces/tabs/history. Like history, favorites are independent of the space↔tab graph: the
  /// store reads/writes its own `Favorite` rows directly and is not part of `save(_:)`/`load()`.
  public func makeFavoritesStore() -> FavoritesStore {
    FavoritesStore(modelContext: container.mainContext)
  }

  /// Vends a `DownloadStore` backed by this same container, so the downloads log lives in the one
  /// store file alongside spaces/tabs/history/favorites. Like history, downloads are independent of the
  /// space↔tab graph: the store reads/writes its own `DownloadRecord` rows directly and is not part of
  /// `save(_:)`/`load()`.
  public func makeDownloadStore() -> DownloadStore {
    DownloadStore(modelContext: container.mainContext)
  }

  // MARK: - Restore

  /// Rebuilds a live `SpaceStore` from persisted records, or returns `nil` when the store is empty
  /// (first-ever launch) so the caller can seed the default space. Spaces and tabs come back in their
  /// saved order, with the previously-active space and per-space active tab restored.
  public func load() -> SpaceStore? {
    let descriptor = FetchDescriptor<SpaceRecord>(sortBy: [SortDescriptor(\.order)])
    guard let records = try? context.fetch(descriptor), !records.isEmpty else { return nil }

    // Guarantee exactly one Personal profile survives restore. Pre-migration stores (and any store
    // that somehow lost the flag) have none; promote the first space so the main user's identity and
    // the "can't delete Personal" invariant still hold.
    let hasPersonal = records.contains { $0.isPersonal }

    let spaces = records.enumerated().map { index, record -> Space in
      let isPersonal = record.isPersonal || (!hasPersonal && index == 0)
      let tabRecords = record.tabs.sorted { $0.order < $1.order }
      // Archived tabs come back as lightweight records (no live web view), not open tabs.
      let openRecords = tabRecords.filter { !$0.isArchived }
      let archivedTabs = tabRecords
        .filter(\.isArchived)
        .map { ArchivedTab(id: $0.id, url: $0.url, title: $0.title, lastAccessed: $0.lastAccessed) }
      // A space must always have at least one *open* tab; reseed a blank one if a record has none.
      let webTabs: [WebTab] = openRecords.isEmpty
        ? [WebTab()]
        : openRecords.map { tab in
            WebTab(
              id: tab.id,
              url: tab.url,
              title: tab.title,
              isPinned: tab.isPinned,
              lastAccessed: tab.lastAccessed,
              deferLoad: true
            )
          }
      let tabManager = TabManager(tabs: webTabs, activeTabID: record.activeTabID, archivedTabs: archivedTabs)
      return Space(
        id: record.id,
        name: record.name,
        colorHex: record.colorHex,
        icon: record.icon,
        isPersonal: isPersonal,
        tabManager: tabManager,
        proxyConfigString: record.proxyConfigString,
        proxyEnabled: record.proxyEnabled
      )
    }

    let activeSpaceID = defaults.string(forKey: Self.activeSpaceKey).flatMap(UUID.init(uuidString:))
    return SpaceStore(spaces: spaces, activeSpaceID: activeSpaceID)
  }

  // MARK: - Save

  /// Snapshots the live `SpaceStore` into the store: upsert every space/tab by id, write array
  /// indices as `order`, and delete records whose live counterparts are gone (cascade removes a
  /// deleted space's tabs). A deferred tab that never loaded still round-trips, because its saved
  /// url/title were seeded onto the live `WebTab` at restore.
  public func save(_ store: SpaceStore) {
    let existingSpaces = (try? context.fetch(FetchDescriptor<SpaceRecord>())) ?? []
    var spaceByID = Dictionary(existingSpaces.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    let liveSpaceIDs = Set(store.spaces.map(\.id))
    for space in existingSpaces where !liveSpaceIDs.contains(space.id) {
      context.delete(space)
      spaceByID[space.id] = nil
    }

    for (spaceIndex, space) in store.spaces.enumerated() {
      let manager = space.tabManager
      let record = spaceByID[space.id] ?? {
        let new = SpaceRecord(
          id: space.id, name: space.name, colorHex: space.colorHex,
          icon: space.icon, order: spaceIndex, isPersonal: space.isPersonal
        )
        context.insert(new)
        spaceByID[space.id] = new
        return new
      }()
      record.name = space.name
      record.colorHex = space.colorHex
      record.icon = space.icon
      record.order = spaceIndex
      record.activeTabID = manager.activeTabID
      record.isPersonal = space.isPersonal
      record.proxyConfigString = space.proxyConfigString
      record.proxyEnabled = space.proxyEnabled

      reconcileTabs(of: manager, into: record)
    }

    defaults.set(store.activeSpaceID?.uuidString, forKey: Self.activeSpaceKey)
    try? context.save()
  }

  /// Upserts a space's open *and* archived tabs into its `SpaceRecord`, writing display order and the
  /// `isArchived` flag, and deleting records whose live counterparts (open or archived) are gone.
  private func reconcileTabs(of manager: TabManager, into record: SpaceRecord) {
    var tabByID = Dictionary(record.tabs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    // An id still present in either the open or the archived list must be kept; everything else dropped.
    let keepIDs = Set(manager.tabs.map(\.id)).union(manager.archivedTabs.map(\.id))
    for tab in record.tabs where !keepIDs.contains(tab.id) {
      context.delete(tab)
      tabByID[tab.id] = nil
    }

    for (tabIndex, tab) in manager.tabs.enumerated() {
      if let existing = tabByID[tab.id] {
        existing.url = tab.url
        existing.title = tab.title
        existing.order = tabIndex
        existing.isPinned = tab.isPinned
        existing.lastAccessed = tab.lastAccessed
        existing.isArchived = false
      } else {
        let new = TabRecord(
          id: tab.id, url: tab.url, title: tab.title, order: tabIndex,
          isPinned: tab.isPinned, lastAccessed: tab.lastAccessed
        )
        new.space = record
        context.insert(new)
      }
    }

    // Archived tabs persist as `isArchived` records (no live web view to snapshot). Their `order` is
    // their index within the archived list — only meaningful relative to other archived records.
    for (archiveIndex, archived) in manager.archivedTabs.enumerated() {
      if let existing = tabByID[archived.id] {
        existing.url = archived.url
        existing.title = archived.title
        existing.order = archiveIndex
        existing.isPinned = false
        existing.lastAccessed = archived.lastAccessed
        existing.isArchived = true
      } else {
        let new = TabRecord(
          id: archived.id, url: archived.url, title: archived.title, order: archiveIndex,
          isPinned: false, lastAccessed: archived.lastAccessed, isArchived: true
        )
        new.space = record
        context.insert(new)
      }
    }
  }

  // MARK: - Reset

  /// Clears the entire store (dev/debug). Used by the reset menu item and the `BROWSER_RESET_STORE`
  /// launch flag so a fresh run seeds the default space.
  ///
  /// Deletes objects individually rather than via `delete(model:)` batch deletes — a batch delete
  /// trips the mandatory space↔tab inverse constraint. Deleting each `SpaceRecord` cascades to its
  /// tabs; any stray orphan tabs are then swept up.
  public func reset() {
    for space in (try? context.fetch(FetchDescriptor<SpaceRecord>())) ?? [] {
      context.delete(space)
    }
    for tab in (try? context.fetch(FetchDescriptor<TabRecord>())) ?? [] {
      context.delete(tab)
    }
    // Favorites are keyed by space id; once every space is gone they'd be orphaned, so a fresh-run
    // reset clears them too (unlike history, which is deliberately kept across resets).
    for favorite in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] {
      context.delete(favorite)
    }
    defaults.removeObject(forKey: Self.activeSpaceKey)
    try? context.save()
  }
}
