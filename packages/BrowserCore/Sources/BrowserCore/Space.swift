import Foundation
import Observation

/// A named, colored container of tabs — the app's "Space" (Work, Personal, a project).
///
/// A Space owns its own `TabManager`, so its tabs and active tab are fully independent of every
/// other Space. Tab ownership is therefore unambiguous: **a tab lives in exactly one Space's
/// `TabManager`.** This type is a platform-agnostic value-holder — it stores a `colorHex` string
/// and an SF Symbol `icon` name rather than any UI color/image, so it stays serializable for the
/// persistence layer (Prompt 06). The hosting app decides what a Space's tabs load.
@Observable
@MainActor
public final class Space: Identifiable {
  /// Stable identity for the lifetime of the space. `@ObservationIgnored` because it never changes.
  @ObservationIgnored
  public let id = UUID()

  /// User-facing name, e.g. "Work".
  public var name: String
  /// Accent color as a hex string (e.g. `"#3B82F6"`). The UI maps this to a concrete color.
  public var colorHex: String
  /// SF Symbol name for the space's glyph, e.g. `"briefcase"`.
  public var icon: String

  /// The space's own tabs and active tab. `@ObservationIgnored` like `WebTab.webView`: the
  /// reference never changes, and its contents are observed through the `TabManager` itself.
  @ObservationIgnored
  public let tabManager: TabManager

  /// Creates a space. `tabManager` defaults to a fresh `TabManager`, which seeds one blank tab, so
  /// a new space is immediately usable.
  public init(
    name: String,
    colorHex: String,
    icon: String,
    tabManager: TabManager = TabManager()
  ) {
    self.name = name
    self.colorHex = colorHex
    self.icon = icon
    self.tabManager = tabManager
  }
}
