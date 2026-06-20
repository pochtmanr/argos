import Foundation
import Observation
import SwiftData
import WebKit

/// Records and tracks file downloads. Owns a `ModelContext` (shared with `SessionPersistence` in
/// production via ``SessionPersistence/makeDownloadStore()``) and keeps an observable `items` cache so
/// the downloads popover updates live as a download progresses or finishes.
///
/// Like `HistoryStore`, downloads are a flat log independent of the space↔tab graph: this store talks
/// to SwiftData directly (insert/fetch/delete `DownloadRecord`) and is not part of
/// `SessionPersistence.save(_:)`/`load()`. The value type it hands back is ``DownloadItem``, never the
/// `@Model`.
///
/// **Progress vs. persistence.** Byte progress arrives many times a second, so it is applied only to
/// the in-memory `items` (no SwiftData write per tick). The store writes to disk only at state
/// transitions — start, destination decided, and the terminal finish/fail/cancel — so a relaunch
/// shows the last-known terminal state without thrashing the store. We don't resume partials: a row
/// still `inProgress` at launch is rewritten to `failed` in ``init(modelContext:)``.
@Observable
@MainActor
public final class DownloadStore {
  /// All downloads, newest first. The single source of truth the popover binds to.
  public private(set) var items: [DownloadItem] = []

  @ObservationIgnored
  private let context: ModelContext

  /// Strong reference to a container this store created itself (the `inMemory` path); `nil` in
  /// production where `SessionPersistence` owns the shared container. Mirrors `HistoryStore`.
  @ObservationIgnored
  private let ownedContainer: ModelContainer?

  /// Per-download delegates, kept alive while a download runs (WebKit holds the delegate weakly) and
  /// dropped at the terminal transition. Presence also marks a download as still cancellable.
  @ObservationIgnored
  private var coordinators: [UUID: DownloadCoordinator] = [:]

  /// The live `WKDownload`s, so ``cancel(_:)`` can stop one mid-flight.
  @ObservationIgnored
  private var downloads: [UUID: WKDownload] = [:]

  /// Production initializer: use the container's main context (shared with `SessionPersistence`).
  public init(modelContext: ModelContext) {
    self.context = modelContext
    self.ownedContainer = nil
    recoverStaleAndReload()
  }

  /// Stands up an isolated store for tests and as a persistence-less fallback.
  public init(inMemory: Bool) throws {
    let schema = Schema([DownloadRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    let container = try ModelContainer(for: schema, configurations: configuration)
    self.ownedContainer = container
    self.context = container.mainContext
    recoverStaleAndReload()
  }

  // MARK: - Lifecycle

  /// Begins tracking a `WKDownload` that WebKit handed us (a response the engine can't render, or a
  /// link with the `download` attribute). Inserts an `inProgress` record and installs a per-download
  /// `WKDownloadDelegate` **synchronously** — WebKit requires `download.delegate` set before the
  /// `didBecome download:` callback returns.
  public func start(_ download: WKDownload) {
    let id = UUID()
    let record = DownloadRecord(
      id: id,
      filename: download.originalRequest?.url?.lastPathComponent ?? "download",
      destinationPath: "",
      sourceURL: download.originalRequest?.url,
      totalBytes: 0,
      bytesReceived: 0,
      stateRaw: DownloadState.inProgress.rawValue,
      startedAt: Date()
    )
    context.insert(record)

    let coordinator = DownloadCoordinator(id: id, download: download, store: self)
    download.delegate = coordinator
    coordinators[id] = coordinator
    downloads[id] = download
    persist()
  }

  /// Cancels an in-flight download (no-op once it has reached a terminal state). Resume data is
  /// discarded — v1 doesn't resume partials.
  public func cancel(_ id: UUID) {
    guard coordinators[id] != nil, let download = downloads[id] else { return }
    download.cancel { _ in }
    markCancelled(id: id)
  }

  /// Removes one download from the list (and cancels it first if still running). Does not delete the
  /// file on disk.
  public func remove(_ id: UUID) {
    if coordinators[id] != nil { downloads[id]?.cancel { _ in } }
    if let record = fetchRecord(id: id) { context.delete(record) }
    cleanup(id)
    persist()
  }

  /// Clears every finished/failed/cancelled download, leaving in-progress ones running.
  public func clearCompleted() {
    let terminal = [DownloadState.finished, .failed, .cancelled].map(\.rawValue)
    let descriptor = FetchDescriptor<DownloadRecord>(
      predicate: #Predicate { terminal.contains($0.stateRaw) }
    )
    for record in (try? context.fetch(descriptor)) ?? [] { context.delete(record) }
    persist()
  }

  // MARK: - Delegate callbacks (from DownloadCoordinator, on the main actor)

  /// WebKit settled on a destination: record the final filename, path, size, and source URL.
  fileprivate func didDecideDestination(id: UUID, destination: URL, totalBytes: Int64, sourceURL: URL?) {
    guard let record = fetchRecord(id: id) else { return }
    record.filename = destination.lastPathComponent
    record.destinationPath = destination.path
    record.totalBytes = max(0, totalBytes)
    if let sourceURL { record.sourceURL = sourceURL }
    persist()
  }

  /// A progress tick: update only the in-memory item (no SwiftData write — see the type doc).
  fileprivate func updateProgress(id: UUID, bytesReceived: Int64, totalBytes: Int64) {
    guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .inProgress else { return }
    let current = items[index]
    items[index] = DownloadItem(
      id: current.id,
      filename: current.filename,
      destinationPath: current.destinationPath,
      sourceURL: current.sourceURL,
      totalBytes: totalBytes > 0 ? totalBytes : current.totalBytes,
      bytesReceived: bytesReceived,
      state: .inProgress,
      startedAt: current.startedAt
    )
  }

  fileprivate func markFinished(id: UUID) { finish(id: id, state: .finished) }

  fileprivate func markFailed(id: UUID) { finish(id: id, state: .failed) }

  fileprivate func markCancelled(id: UUID) { finish(id: id, state: .cancelled) }

  // MARK: - Internals

  /// Applies a terminal state once, writing the final byte count and dropping the live download/
  /// coordinator. The `coordinators[id]` guard makes the transition idempotent — e.g. a
  /// `didFailWithError(cancelled)` arriving after ``cancel(_:)`` already handled it is ignored.
  private func finish(id: UUID, state: DownloadState) {
    guard coordinators[id] != nil, let record = fetchRecord(id: id) else { return }
    if let item = items.first(where: { $0.id == id }) {
      record.bytesReceived = item.bytesReceived
      if record.totalBytes == 0 { record.totalBytes = item.bytesReceived }
    }
    if state == .finished, record.totalBytes > 0 { record.bytesReceived = record.totalBytes }
    record.stateRaw = state.rawValue
    cleanup(id)
    persist()
  }

  private func cleanup(_ id: UUID) {
    coordinators[id]?.invalidate()
    coordinators[id] = nil
    downloads[id] = nil
  }

  /// Saves pending changes and refreshes the observable cache.
  private func persist() {
    try? context.save()
    reload()
  }

  private func reload() {
    let descriptor = FetchDescriptor<DownloadRecord>(
      sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
    )
    let records = (try? context.fetch(descriptor)) ?? []
    items = records.map {
      DownloadItem(
        id: $0.id,
        filename: $0.filename,
        destinationPath: $0.destinationPath,
        sourceURL: $0.sourceURL,
        totalBytes: $0.totalBytes,
        bytesReceived: $0.bytesReceived,
        state: DownloadState(rawValue: $0.stateRaw) ?? .failed,
        startedAt: $0.startedAt
      )
    }
  }

  /// At launch, any row still `inProgress` is a partial from a prior session we won't resume — rewrite
  /// it to `failed` so the list reflects a true terminal state. Then load the cache.
  private func recoverStaleAndReload() {
    // String literal matches `DownloadState.inProgress.rawValue`; #Predicate can't reference the enum.
    let descriptor = FetchDescriptor<DownloadRecord>(predicate: #Predicate { $0.stateRaw == "inProgress" })
    for record in (try? context.fetch(descriptor)) ?? [] {
      record.stateRaw = DownloadState.failed.rawValue
    }
    try? context.save()
    reload()
  }

  private func fetchRecord(id: UUID) -> DownloadRecord? {
    let descriptor = FetchDescriptor<DownloadRecord>(predicate: #Predicate { $0.id == id })
    return try? context.fetch(descriptor).first
  }

  // MARK: - Destination

  /// The user's Downloads directory, falling back to `~/Downloads` if the system query fails.
  static func downloadsDirectory() -> URL {
    let fm = FileManager.default
    if let url = try? fm.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
      return url
    }
    return fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
  }

  /// A non-colliding destination in `directory` for `suggestedFilename`: if `name.ext` exists, tries
  /// `name (1).ext`, `name (2).ext`, … until a free name is found. Pure (no store/actor state) so it
  /// is unit-testable against a temp directory.
  static func uniqueURL(in directory: URL, for suggestedFilename: String) -> URL {
    let fm = FileManager.default
    let name = suggestedFilename.isEmpty ? "download" : suggestedFilename
    var candidate = directory.appendingPathComponent(name)
    guard fm.fileExists(atPath: candidate.path) else { return candidate }

    let ext = candidate.pathExtension
    let base = candidate.deletingPathExtension().lastPathComponent
    var counter = 1
    repeat {
      let suffixed = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
      candidate = directory.appendingPathComponent(suffixed)
      counter += 1
    } while fm.fileExists(atPath: candidate.path)
    return candidate
  }
}

/// Per-download `WKDownloadDelegate`, one instance per active download — mirrors `WebTab`'s private
/// `NavigationProxy`. Routes WebKit's destination/finish/fail callbacks (delivered on the main thread)
/// back into the owning `DownloadStore`, and KVO-observes byte progress (which may fire off the main
/// thread, so it hops to the main actor).
final class DownloadCoordinator: NSObject, WKDownloadDelegate {
  private let id: UUID
  private weak var store: DownloadStore?
  private var progressObservation: NSKeyValueObservation?

  init(id: UUID, download: WKDownload, store: DownloadStore) {
    self.id = id
    self.store = store
    super.init()

    let downloadID = id
    progressObservation = download.progress.observe(\.completedUnitCount, options: [.new]) { [weak store] progress, _ in
      let received = progress.completedUnitCount
      let total = progress.totalUnitCount
      Task { @MainActor in store?.updateProgress(id: downloadID, bytesReceived: received, totalBytes: total) }
    }
  }

  func invalidate() {
    progressObservation?.invalidate()
    progressObservation = nil
  }

  func download(
    _ download: WKDownload,
    decideDestinationUsing response: URLResponse,
    suggestedFilename: String
  ) async -> URL? {
    // `WKDownloadDelegate` is `@MainActor`-isolated, so this runs on the main actor (same actor as the
    // store) — the call is synchronous. Pick a non-colliding path in ~/Downloads and record it.
    let destination = DownloadStore.uniqueURL(in: DownloadStore.downloadsDirectory(), for: suggestedFilename)
    store?.didDecideDestination(id: id, destination: destination, totalBytes: response.expectedContentLength, sourceURL: response.url)
    return destination
  }

  func downloadDidFinish(_ download: WKDownload) {
    MainActor.assumeIsolated { store?.markFinished(id: id) }
  }

  func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
    MainActor.assumeIsolated {
      // A user cancel reports `.cancelled`; `markCancelled` is a no-op if `cancel(_:)` already ran.
      if (error as? URLError)?.code == .cancelled {
        store?.markCancelled(id: id)
      } else {
        store?.markFailed(id: id)
      }
    }
  }
}
