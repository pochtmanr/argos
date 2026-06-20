import Foundation

/// Where a download is in its lifecycle. `inProgress` is the only live state; the other three are
/// terminal and are what survives relaunch (a lingering `inProgress` row is mapped to `failed` on
/// load, since we don't resume partials).
public enum DownloadState: String, Equatable, Sendable {
  case inProgress
  case finished
  case failed
  case cancelled
}

/// A lightweight, `Sendable` value-type view of a download that the downloads popover binds to —
/// decoupled from the SwiftData `DownloadRecord` the same way ``HistoryEntry`` is decoupled from
/// `HistoryRecord`. `DownloadStore` rebuilds these from records (and mutates the in-memory copy as
/// progress ticks in) so the UI updates live without the `@Model` ever leaving the store.
public struct DownloadItem: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let filename: String
  /// Filesystem path of the destination; ``destinationURL`` reconstructs a file URL for Finder/open.
  public let destinationPath: String
  public let sourceURL: URL?
  /// Total expected bytes, or `0` when the server didn't report a length (progress is then unknown).
  public let totalBytes: Int64
  public let bytesReceived: Int64
  public let state: DownloadState
  public let startedAt: Date

  public init(
    id: UUID,
    filename: String,
    destinationPath: String,
    sourceURL: URL?,
    totalBytes: Int64,
    bytesReceived: Int64,
    state: DownloadState,
    startedAt: Date
  ) {
    self.id = id
    self.filename = filename
    self.destinationPath = destinationPath
    self.sourceURL = sourceURL
    self.totalBytes = totalBytes
    self.bytesReceived = bytesReceived
    self.state = state
    self.startedAt = startedAt
  }

  /// A file URL for the saved (or intended) destination, for reveal-in-Finder / open.
  public var destinationURL: URL {
    URL(fileURLWithPath: destinationPath)
  }

  /// Completed fraction in `0...1`, or `nil` when the total size is unknown (so the UI can show an
  /// indeterminate bar). Always `1` once finished.
  public var fractionCompleted: Double? {
    if state == .finished { return 1 }
    guard totalBytes > 0 else { return nil }
    return min(1, Double(bytesReceived) / Double(totalBytes))
  }
}
