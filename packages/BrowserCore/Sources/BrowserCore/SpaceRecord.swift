import Foundation
import SwiftData

/// The persisted (at-rest) shape of a `Space`. Deliberately separate from the live `Space`/`WebTab`
/// graph — those own `WKWebView`s and observation state that must never be serialized. The
/// persistence layer maps `SpaceRecord ↔ Space` on load/save.
///
/// All stored properties have defaults so SwiftData's automatic **lightweight migration** can add new
/// columns to an existing store without wiping data. A future *breaking* change (renames, type
/// changes, splits) will need an explicit `VersionedSchema` + `SchemaMigrationPlan`.
@Model
public final class SpaceRecord {
  /// Matches `Space.id`. Unique so save can upsert by id rather than duplicating rows.
  @Attribute(.unique) public var id: UUID
  /// User-facing name, e.g. "Work".
  public var name: String
  /// Accent color as a hex string (e.g. `"#3B82F6"`).
  public var colorHex: String
  /// SF Symbol name for the space's glyph.
  public var icon: String
  /// Position in the space switcher; the save path writes the array index here.
  public var order: Int
  /// Which of this space's tabs was active. Matches a `TabRecord.id` (and `WebTab.id`) in `tabs`.
  public var activeTabID: UUID?

  /// This space's tabs. Cascade delete removes a space's `TabRecord`s with it; the inverse is
  /// `TabRecord.space`. This relationship *is* the persisted space↔tab link (the "spaceID").
  @Relationship(deleteRule: .cascade, inverse: \TabRecord.space)
  public var tabs: [TabRecord] = []

  public init(
    id: UUID,
    name: String,
    colorHex: String,
    icon: String,
    order: Int,
    activeTabID: UUID? = nil
  ) {
    self.id = id
    self.name = name
    self.colorHex = colorHex
    self.icon = icon
    self.order = order
    self.activeTabID = activeTabID
  }
}
