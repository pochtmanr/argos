import Foundation

/// A lightweight, value-type view of an open tab that the suggestion ranker consumes.
///
/// Deliberately decoupled from the `@MainActor` ``WebTab`` (which owns a `WKWebView`) so the ranking
/// logic stays pure, `Sendable`, and unit-testable without WebKit. The host app maps its live tabs
/// into `OpenTab`s before calling ``SuggestionEngine/suggestions(for:openTabs:history:)``.
public struct OpenTab: Identifiable, Equatable, Sendable {
  /// The originating ``WebTab/id``. Used to resolve which tab to switch to when a suggestion is acted on.
  public let id: UUID
  public let title: String
  public let url: URL?

  public init(id: UUID, title: String, url: URL?) {
    self.id = id
    self.title = title
    self.url = url
  }
}

/// A lightweight, `Sendable` view of a favorite the ranker consumes — decoupled from the `@MainActor`
/// `Favorite` `@Model` the same way ``OpenTab`` is decoupled from `WebTab`. The host maps the active
/// Space's favorites into `FavoriteItem`s before calling ``SuggestionEngine/suggestions(for:openTabs:favorites:history:)``.
public struct FavoriteItem: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let title: String
  public let url: URL

  public init(id: UUID, title: String, url: URL) {
    self.id = id
    self.title = title
    self.url = url
  }
}

/// A single browsing-history record: the lightweight, `Sendable` value type the ranker and History
/// UI consume, decoupled from the SwiftData `HistoryRecord` the same way ``OpenTab`` is decoupled from
/// ``WebTab``. `visitedAt`/`visitCount` let the ranker prefer frequent + recent pages; they default
/// so the Prompt 07 call sites that predate them still compile.
public struct HistoryEntry: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let title: String
  public let url: URL
  /// Most-recent visit time (recency signal for ranking; grouping key for the History view).
  public let visitedAt: Date
  /// Number of visits (frequency signal for ranking).
  public let visitCount: Int

  public init(id: UUID, title: String, url: URL, visitedAt: Date = .distantPast, visitCount: Int = 1) {
    self.id = id
    self.title = title
    self.url = url
    self.visitedAt = visitedAt
    self.visitCount = visitCount
  }
}

/// One row of the command bar: the action to take plus how to present it.
public struct Suggestion: Identifiable, Equatable, Sendable {
  /// What acting on this suggestion does.
  public enum Kind: Equatable, Sendable {
    /// Load a direct URL (from ``URLBarParser/Resolution/url(_:)``).
    case navigate(URL)
    /// Run a search (from ``URLBarParser/Resolution/search(_:)``).
    case search(URL)
    /// Jump to an already-open tab with this ``WebTab/id``.
    case switchToTab(tabID: UUID)
    /// Open a history result.
    case history(URL)
    /// Open a saved favorite's URL.
    case favorite(URL)
  }

  public let kind: Kind
  /// Primary display text.
  public let title: String
  /// Secondary display text (resolved URL, host, etc.).
  public let subtitle: String

  /// Deterministic identity derived from `kind`, so the results list keeps stable SwiftUI identity
  /// across keystrokes (no random UUIDs churning `ForEach`).
  public var id: String {
    switch kind {
    case let .navigate(url): return "navigate:\(url.absoluteString)"
    case let .search(url): return "search:\(url.absoluteString)"
    case let .switchToTab(tabID): return "tab:\(tabID.uuidString)"
    case let .history(url): return "history:\(url.absoluteString)"
    case let .favorite(url): return "favorite:\(url.absoluteString)"
    }
  }

  public init(kind: Kind, title: String, subtitle: String) {
    self.kind = kind
    self.title = title
    self.subtitle = subtitle
  }
}

/// Produces the mixed command-bar results for a query: a URL/search action plus matching open tabs
/// (ranked by relevance), and — once Prompt 08 lands — history matches.
///
/// Pure and `Sendable`; reuses ``URLBarParser`` for the URL-vs-search decision so the command bar and
/// the address bar agree on what a string means.
public struct SuggestionEngine: Sendable {
  public var parser: URLBarParser

  public init(parser: URLBarParser = URLBarParser()) {
    self.parser = parser
  }

  /// Builds the ordered suggestion list for `query`.
  ///
  /// Ordering: the URL/search action always comes first (the default highlight, so Enter navigates to
  /// exactly what was typed), then favorites (the user's curated quick-access set), then open-tab
  /// matches ranked by relevance, then history matches ranked by relevance + frequency + recency. A
  /// blank query yields no suggestions — nothing is actionable, and we never dump every row.
  public func suggestions(for query: String,
                          openTabs: [OpenTab],
                          favorites: [FavoriteItem] = [],
                          history: [HistoryEntry] = []) -> [Suggestion] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let tabs = tabSuggestions(for: trimmed, openTabs: openTabs)
    // Don't repeat a page as history if it's already offered as an open tab or a favorite.
    let openTabURLs = Set(openTabs.compactMap { $0.url })
    let favoriteURLs = Set(favorites.map { $0.url })

    var result: [Suggestion] = [urlAction(for: trimmed)]
    result += favoriteSuggestions(for: trimmed, favorites: favorites)
    result += tabs
    result += historySuggestions(for: trimmed, history: history,
                                 excludingURLs: openTabURLs.union(favoriteURLs))
    return result
  }

  // MARK: - URL / search action

  private func urlAction(for query: String) -> Suggestion {
    switch parser.classify(query) {
    case let .url(url):
      return Suggestion(kind: .navigate(url), title: query, subtitle: url.absoluteString)
    case let .search(url):
      return Suggestion(kind: .search(url), title: "Search for “\(query)”", subtitle: url.absoluteString)
    }
  }

  // MARK: - Favorites ranking

  /// Favorites matching `query`, ranked by relevance (same scoring as tabs): score desc, then shorter
  /// title, then original order. Emitted as `.favorite` actions that open the saved URL.
  private func favoriteSuggestions(for query: String, favorites: [FavoriteItem]) -> [Suggestion] {
    let needle = query.lowercased()

    return favorites.enumerated()
      .compactMap { index, favorite -> (score: Int, length: Int, index: Int, favorite: FavoriteItem)? in
        guard let score = matchScore(needle: needle, title: favorite.title, url: favorite.url) else { return nil }
        return (score, favorite.title.count, index, favorite)
      }
      .sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.length != rhs.length { return lhs.length < rhs.length }
        return lhs.index < rhs.index
      }
      .map { ranked in
        let favorite = ranked.favorite
        let title = favorite.title.isEmpty ? (favorite.url.host() ?? favorite.url.absoluteString) : favorite.title
        return Suggestion(kind: .favorite(favorite.url), title: title, subtitle: favorite.url.absoluteString)
      }
  }

  // MARK: - Open-tab ranking

  private func tabSuggestions(for query: String, openTabs: [OpenTab]) -> [Suggestion] {
    let needle = query.lowercased()

    // Score, drop non-matches, then sort by score desc; ties broken by shorter title then original
    // order (`enumerated` index) so the ranking is stable.
    return openTabs.enumerated()
      .compactMap { index, tab -> (score: Int, length: Int, index: Int, tab: OpenTab)? in
        guard let score = matchScore(needle: needle, tab: tab) else { return nil }
        return (score, tab.title.count, index, tab)
      }
      .sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.length != rhs.length { return lhs.length < rhs.length }
        return lhs.index < rhs.index
      }
      .map { ranked in
        let tab = ranked.tab
        let title = tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title
        return Suggestion(kind: .switchToTab(tabID: tab.id),
                          title: title,
                          subtitle: tab.url?.absoluteString ?? "")
      }
  }

  private func matchScore(needle: String, tab: OpenTab) -> Int? {
    matchScore(needle: needle, title: tab.title, url: tab.url)
  }

  /// Higher is a better match. `nil` means it does not match at all. Shared by open-tab and history
  /// ranking so the command bar scores both the same way.
  private func matchScore(needle: String, title: String, url: URL?) -> Int? {
    let title = title.lowercased()
    let urlString = url?.absoluteString.lowercased() ?? ""
    let host = url?.host()?.lowercased() ?? ""

    if title.hasPrefix(needle) { return 5 }
    if hasWordBoundaryPrefix(title, needle) { return 4 }
    if title.contains(needle) { return 3 }
    if host.hasPrefix(needle) { return 2 }
    if urlString.contains(needle) { return 1 }
    return nil
  }

  // MARK: - History ranking

  /// Up to `limit` history matches for `query`, ranked by relevance, then frequency (`visitCount`),
  /// then recency (`visitedAt`). URLs in `excludingURLs` (already offered as open tabs) are dropped so
  /// the same page never appears twice.
  private func historySuggestions(for query: String,
                                  history: [HistoryEntry],
                                  excludingURLs: Set<URL>,
                                  limit: Int = 5) -> [Suggestion] {
    let needle = query.lowercased()

    return history
      .filter { !excludingURLs.contains($0.url) }
      .compactMap { entry -> (score: Int, entry: HistoryEntry)? in
        guard let score = matchScore(needle: needle, title: entry.title, url: entry.url) else { return nil }
        return (score, entry)
      }
      .sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.entry.visitCount != rhs.entry.visitCount { return lhs.entry.visitCount > rhs.entry.visitCount }
        return lhs.entry.visitedAt > rhs.entry.visitedAt
      }
      .prefix(limit)
      .map { ranked in
        let entry = ranked.entry
        let title = entry.title.isEmpty ? (entry.url.host() ?? entry.url.absoluteString) : entry.title
        return Suggestion(kind: .history(entry.url), title: title, subtitle: entry.url.absoluteString)
      }
  }

  /// True when any whitespace/punctuation-delimited word in `text` starts with `needle`.
  private func hasWordBoundaryPrefix(_ text: String, _ needle: String) -> Bool {
    text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .contains { $0.hasPrefix(needle) }
  }
}
