import Foundation
import SwiftData

/// The persisted (at-rest) shape of a download: one row per download attempt. `DownloadStore` maps
/// `DownloadRecord ↔ DownloadItem` (the lightweight value type the UI consumes), mirroring the
/// `HistoryRecord ↔ HistoryEntry` split — the live/value side never touches SwiftData.
///
/// We persist the destination as a `path` string rather than a `URL` so a row still round-trips when
/// the file is later moved or deleted (the file may be gone, but the record — and its last-known
/// location — survives relaunch). The download `state` is stored as its raw string for the same
/// forward-compatibility reason SwiftData favors plain scalars.
@Model
public final class DownloadRecord {
  /// Stable identity, surfaced to the UI as `DownloadItem.id` so a row can be cancelled/removed by id.
  @Attribute(.unique) public var id: UUID
  /// The saved file's name (the uniquified destination's last path component).
  public var filename: String
  /// Filesystem path of the destination in `~/Downloads`. Stored as a path (not a `URL`) so the row
  /// round-trips even after the file is moved or deleted.
  public var destinationPath: String
  /// The URL the download originated from, when known (used only for display).
  public var sourceURL: URL?
  /// Total expected bytes, or `0` when the server didn't report a length.
  public var totalBytes: Int64
  /// Bytes written so far. Persisted only at state transitions (not on every progress tick).
  public var bytesReceived: Int64
  /// `DownloadState.rawValue`. Lingering `inProgress` rows are surfaced as `failed` on next launch
  /// (we don't resume partials).
  public var stateRaw: String
  /// When the download began; the popover sorts by this (newest first).
  public var startedAt: Date

  public init(
    id: UUID,
    filename: String,
    destinationPath: String,
    sourceURL: URL?,
    totalBytes: Int64,
    bytesReceived: Int64,
    stateRaw: String,
    startedAt: Date
  ) {
    self.id = id
    self.filename = filename
    self.destinationPath = destinationPath
    self.sourceURL = sourceURL
    self.totalBytes = totalBytes
    self.bytesReceived = bytesReceived
    self.stateRaw = stateRaw
    self.startedAt = startedAt
  }
}
