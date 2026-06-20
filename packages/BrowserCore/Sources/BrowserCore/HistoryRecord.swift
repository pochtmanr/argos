import Foundation
import SwiftData

/// The persisted (at-rest) shape of a browsing-history entry: one row per visited URL, carrying a
/// `visitCount` and the most-recent `visitedAt` rather than a separate row per visit. `HistoryStore`
/// maps `HistoryRecord ↔ HistoryEntry` (the lightweight value type the ranker/UI consume), mirroring
/// the `TabRecord ↔ WebTab` split — the live/value side never touches SwiftData.
///
/// De-duplication (collapsing repeat visits into one row) is done in `HistoryStore`, keyed on the
/// URL string, so only `id` is unique here.
@Model
public final class HistoryRecord {
  /// Stable identity, surfaced to the UI as `HistoryEntry.id` so a row can be deleted by id.
  @Attribute(.unique) public var id: UUID
  /// The visited page URL. Always present — history is only recorded for committed http(s) loads.
  public var url: URL
  /// Last known page title for this URL (refreshed on revisit).
  public var title: String
  /// Timestamp of the most recent visit; the History view groups/sorts by this.
  public var visitedAt: Date
  /// How many times this URL has been visited (rapid repeats are not counted — see `HistoryStore`).
  public var visitCount: Int = 1

  public init(
    id: UUID,
    url: URL,
    title: String,
    visitedAt: Date,
    visitCount: Int = 1
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.visitedAt = visitedAt
    self.visitCount = visitCount
  }
}
