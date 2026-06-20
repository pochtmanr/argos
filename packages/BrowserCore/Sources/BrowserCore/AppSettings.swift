import Foundation
import Observation

/// User-facing app preferences surfaced by the macOS Settings scene (Prompt 13): the default search
/// engine, the new-tab/home page, whether the prior session is restored on launch, and the sidebar's
/// default width. Backed by `UserDefaults` so choices survive launches; `@Observable` so controls
/// bound to a property — and any view reading it — update live.
///
/// Mirrors `ArchiveSettings`'s shape (injectable `defaults`, `@ObservationIgnored` store, didSet-persist)
/// so the two read the same way. The auto-archive threshold stays in `ArchiveSettings`; this type owns
/// everything else the Settings scene edits.
@Observable
@MainActor
public final class AppSettings {
  // MARK: Defaults

  /// Google. The query is percent-encoded and appended to this template by ``URLBarParser``.
  public static let defaultSearchTemplate = "https://www.google.com/search?q="
  /// Apple's home page — a safe, fast first page for a fresh tab/space.
  public static let defaultHomeURLString = "https://www.apple.com"
  /// Restore the previous session by default; the app feels stateful out of the box.
  public static let defaultRestoreOnLaunch = true
  /// Matches the historical `ideal:` sidebar width so existing layouts are unchanged on first run.
  public static let defaultSidebarIdealWidth: Double = 240

  /// Hard fallback used when the stored/typed home URL can't be parsed, so ``homeURL`` is never nil.
  private static let fallbackHomeURL = URL(string: defaultHomeURLString)!

  /// The built-in search engines offered by the Settings picker. `template` matches
  /// ``URLBarParser/searchTemplate`` (query percent-encoded and appended).
  public static let searchEngines: [(name: String, template: String)] = [
    ("Google", "https://www.google.com/search?q="),
    ("DuckDuckGo", "https://duckduckgo.com/?q="),
    ("Bing", "https://www.bing.com/search?q="),
    ("Brave", "https://search.brave.com/search?q="),
  ]

  // MARK: Storage keys

  private enum Key {
    static let searchTemplate = "settings.searchTemplate"
    static let homeURL = "settings.homeURLString"
    static let restoreOnLaunch = "settings.restoreOnLaunch"
    static let sidebarIdealWidth = "settings.sidebarIdealWidth"
  }

  @ObservationIgnored
  private let defaults: UserDefaults

  // MARK: Properties (persist on set)

  /// Search-engine template for the address bar and command bar. Persists on set.
  public var searchTemplate: String {
    didSet { defaults.set(searchTemplate, forKey: Key.searchTemplate) }
  }

  /// The page a fresh tab/space opens, as raw text (so the Settings field can hold in-progress edits).
  /// Read ``homeURL`` for the parsed value. Persists on set.
  public var homeURLString: String {
    didSet { defaults.set(homeURLString, forKey: Key.homeURL) }
  }

  /// When true, the prior session is reloaded on launch; when false, the app starts with a fresh space.
  /// Persists on set.
  public var restoreOnLaunch: Bool {
    didSet { defaults.set(restoreOnLaunch, forKey: Key.restoreOnLaunch) }
  }

  /// The sidebar's preferred width (the `ideal:` of the split-view column). Persists on set.
  public var sidebarIdealWidth: Double {
    didSet { defaults.set(sidebarIdealWidth, forKey: Key.sidebarIdealWidth) }
  }

  // MARK: Derived

  /// The home page as a parsed `URL`, falling back to the default if `homeURLString` is empty or
  /// malformed — so callers always get a usable URL.
  public var homeURL: URL {
    let trimmed = homeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil else {
      return Self.fallbackHomeURL
    }
    return url
  }

  // MARK: Init

  /// `defaults` is injectable so tests use a throwaway suite instead of the standard one. Each property
  /// reads its stored value, falling back to the matching default when the key is absent.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.searchTemplate = defaults.string(forKey: Key.searchTemplate) ?? Self.defaultSearchTemplate
    self.homeURLString = defaults.string(forKey: Key.homeURL) ?? Self.defaultHomeURLString
    self.restoreOnLaunch = defaults.object(forKey: Key.restoreOnLaunch) as? Bool ?? Self.defaultRestoreOnLaunch
    let storedWidth = defaults.double(forKey: Key.sidebarIdealWidth)
    self.sidebarIdealWidth = storedWidth > 0 ? storedWidth : Self.defaultSidebarIdealWidth
  }
}
