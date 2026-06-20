import Foundation
import Observation

/// User setting for auto-archive: how long a tab may sit untouched before the archive pass sweeps it
/// out of the sidebar. Backed by `UserDefaults` so it survives launches; `@Observable` so a control
/// bound to `threshold` (and any view reading it) updates live.
///
/// This is the minimal home for the threshold this prompt; the permanent Settings scene (Prompt 13)
/// can adopt the same store. `defaults` is injectable so tests don't touch the standard suite.
@Observable
@MainActor
public final class ArchiveSettings {
  /// Sensible default: tabs idle for 12 hours archive. Used on first launch and when no value is stored.
  public static let defaultThreshold: TimeInterval = 12 * 60 * 60

  private static let key = "autoArchiveThresholdSeconds"

  @ObservationIgnored
  private let defaults: UserDefaults

  /// The idle interval, in seconds, after which a non-pinned, non-active tab archives. Persists on set.
  public var threshold: TimeInterval {
    didSet { defaults.set(threshold, forKey: Self.key) }
  }

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    // `double(forKey:)` returns 0 when the key is absent; treat any non-positive value as "unset".
    let stored = defaults.double(forKey: Self.key)
    self.threshold = stored > 0 ? stored : Self.defaultThreshold
  }
}
