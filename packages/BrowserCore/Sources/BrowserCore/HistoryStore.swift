import Foundation
import Observation
import SwiftData

/// Records and queries browsing history. Owns a `ModelContext` (shared with `SessionPersistence` in
/// production via ``SessionPersistence/makeHistoryStore()``) and keeps an observable `entries` cache —
/// refreshed after every mutation — so SwiftUI (the command bar and History view) updates live.
///
/// History is a flat, query-shaped log, so unlike the space↔tab graph this store talks to SwiftData
/// directly (insert/fetch/delete `HistoryRecord`) instead of going through the live-graph reconcile in
/// `SessionPersistence`. The value type it hands back is ``HistoryEntry`` (the `OpenTab`-style
/// decoupling), never the `@Model`.
@Observable
@MainActor
public final class HistoryStore {
  /// All recorded entries, most-recent first. The single source of truth the UI binds to.
  public private(set) var entries: [HistoryEntry] = []

  /// Repeat visits to the same URL within this window (seconds) refresh the timestamp but do not bump
  /// `visitCount`, so a reload or a redirect chain doesn't inflate the frequency signal.
  private static let dedupeWindow: TimeInterval = 2

  @ObservationIgnored
  private let context: ModelContext

  /// Strong reference to a container this store created itself (the `inMemory` path). `nil` in
  /// production, where `SessionPersistence` owns and outlives the shared container. Held so a
  /// self-made container isn't deallocated out from under `context`.
  @ObservationIgnored
  private let ownedContainer: ModelContainer?

  /// Production initializer: use the container's main context (shared with `SessionPersistence`).
  public init(modelContext: ModelContext) {
    self.context = modelContext
    self.ownedContainer = nil
    reload()
  }

  /// Stands up an isolated store for tests and as a persistence-less fallback, keeping the container
  /// it builds alive for the store's lifetime.
  public init(inMemory: Bool) throws {
    let schema = Schema([HistoryRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    let container = try ModelContainer(for: schema, configurations: configuration)
    self.ownedContainer = container
    self.context = container.mainContext
    reload()
  }

  // MARK: - Recording

  /// Records a committed visit to `url`. Only http(s) URLs are kept (about:blank/file:// etc. are
  /// ignored). One row per URL: a first visit inserts; a later visit bumps `visitCount` and the
  /// timestamp; a rapid repeat (within ``dedupeWindow``) only refreshes the timestamp. `now` is
  /// injectable so de-dupe is deterministically testable.
  ///
  /// A future per-tab private/incognito flag would short-circuit here (deferred this prompt).
  public func record(url: URL, title: String, now: Date = Date()) {
    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }

    if let existing = entries.first(where: { $0.url == url }),
       let record = fetchRecord(id: existing.id) {
      if !title.isEmpty { record.title = title }
      if now.timeIntervalSince(record.visitedAt) >= Self.dedupeWindow {
        record.visitCount += 1
      }
      record.visitedAt = now
    } else {
      context.insert(HistoryRecord(id: UUID(), url: url, title: title, visitedAt: now, visitCount: 1))
    }
    persist()
  }

  // MARK: - Queries

  /// The most recent `limit` entries (already sorted most-recent first).
  public func recent(limit: Int) -> [HistoryEntry] {
    guard limit > 0 else { return [] }
    return Array(entries.prefix(limit))
  }

  /// Entries whose title or URL contains `query` (case-insensitive). A blank query returns every
  /// entry, so the History view can use this for both its idle list and its search field.
  public func search(_ query: String) -> [HistoryEntry] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return entries }
    return entries.filter {
      $0.title.lowercased().contains(needle) || $0.url.absoluteString.lowercased().contains(needle)
    }
  }

  // MARK: - Deletion

  /// Removes a single entry.
  public func delete(_ entry: HistoryEntry) {
    guard let record = fetchRecord(id: entry.id) else { return }
    context.delete(record)
    persist()
  }

  /// Deletes every entry visited at or after `since`; `nil` clears the entire history. Backs the
  /// History view's "clear last hour / today / all" actions.
  public func clear(since: Date?) {
    let toDelete: [HistoryRecord]
    if let since {
      let descriptor = FetchDescriptor<HistoryRecord>(predicate: #Predicate { $0.visitedAt >= since })
      toDelete = (try? context.fetch(descriptor)) ?? []
    } else {
      toDelete = (try? context.fetch(FetchDescriptor<HistoryRecord>())) ?? []
    }
    for record in toDelete { context.delete(record) }
    persist()
  }

  // MARK: - Internals

  /// Saves pending changes and refreshes the observable cache.
  private func persist() {
    try? context.save()
    reload()
  }

  private func reload() {
    let descriptor = FetchDescriptor<HistoryRecord>(
      sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
    )
    let records = (try? context.fetch(descriptor)) ?? []
    entries = records.map {
      HistoryEntry(id: $0.id, title: $0.title, url: $0.url, visitedAt: $0.visitedAt, visitCount: $0.visitCount)
    }
  }

  /// Fetches the managed record for `id` (UUID equality is predicate-safe, unlike URL equality).
  private func fetchRecord(id: UUID) -> HistoryRecord? {
    let descriptor = FetchDescriptor<HistoryRecord>(predicate: #Predicate { $0.id == id })
    return try? context.fetch(descriptor).first
  }
}
