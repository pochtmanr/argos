import Foundation
import XCTest
@testable import BrowserCore

final class SuggestionEngineTests: XCTestCase {
  private let engine = SuggestionEngine()

  private func url(_ string: String) -> URL { URL(string: string)! }

  private func tab(_ title: String, _ urlString: String?) -> OpenTab {
    OpenTab(id: UUID(), title: title, url: urlString.map(url))
  }

  // MARK: - URL action always present & first

  func testURLActionIsFirstForNonEmptyQuery() {
    let tabs = [tab("Example Domain", "https://example.com")]
    let result = engine.suggestions(for: "example.com", openTabs: tabs)
    XCTAssertEqual(result.first?.kind, .navigate(url("https://example.com")))
  }

  func testDomainQueryClassifiesAsNavigate() {
    let result = engine.suggestions(for: "example.com", openTabs: [])
    XCTAssertEqual(result.map(\.kind), [.navigate(url("https://example.com"))])
  }

  func testPhraseQueryClassifiesAsSearch() {
    let result = engine.suggestions(for: "hello world", openTabs: [])
    XCTAssertEqual(result.map(\.kind),
                   [.search(url("https://www.google.com/search?q=hello%20world"))])
  }

  // MARK: - Empty query

  func testEmptyQueryYieldsNoSuggestions() {
    let tabs = [tab("Apple", "https://apple.com")]
    XCTAssertTrue(engine.suggestions(for: "", openTabs: tabs).isEmpty)
  }

  func testWhitespaceQueryYieldsNoSuggestions() {
    let tabs = [tab("Apple", "https://apple.com")]
    XCTAssertTrue(engine.suggestions(for: "   ", openTabs: tabs).isEmpty)
  }

  // MARK: - Open-tab matching

  func testMatchingTabAppearsAfterURLAction() {
    let appleTab = tab("Apple", "https://apple.com")
    let result = engine.suggestions(for: "apple", openTabs: [appleTab])
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[1].kind, .switchToTab(tabID: appleTab.id))
  }

  func testNonMatchingTabsExcluded() {
    let tabs = [tab("Apple", "https://apple.com"), tab("Hacker News", "https://news.ycombinator.com")]
    let result = engine.suggestions(for: "apple", openTabs: tabs)
    let tabIDs = result.compactMap { suggestion -> UUID? in
      if case let .switchToTab(id) = suggestion.kind { return id }
      return nil
    }
    XCTAssertEqual(tabIDs, [tabs[0].id])
  }

  func testMatchingIsCaseInsensitive() {
    let appleTab = tab("Apple", "https://apple.com")
    let result = engine.suggestions(for: "APPLE", openTabs: [appleTab])
    XCTAssertEqual(result.last?.kind, .switchToTab(tabID: appleTab.id))
  }

  func testTabMatchesOnURLWhenTitleDoesNot() {
    let tabs = [tab("Untitled", "https://swift.org/blog")]
    let result = engine.suggestions(for: "swift.org", openTabs: tabs)
    XCTAssertEqual(result.last?.kind, .switchToTab(tabID: tabs[0].id))
  }

  // MARK: - Ranking

  func testTitlePrefixBeatsURLOnlyMatch() {
    let prefix = tab("Swift Forums", "https://forums.swift.org")     // title prefix → score 5
    let urlOnly = tab("Untitled", "https://example.com/swift")       // url substring → score 1
    let result = engine.suggestions(for: "swift", openTabs: [urlOnly, prefix])

    let rankedTabIDs = result.compactMap { suggestion -> UUID? in
      if case let .switchToTab(id) = suggestion.kind { return id }
      return nil
    }
    XCTAssertEqual(rankedTabIDs, [prefix.id, urlOnly.id])
  }

  func testTitlePrefixBeatsTitleSubstring() {
    let prefix = tab("Swift Programming", "https://a.com")            // prefix → score 5
    let substring = tab("Learning Swift", "https://b.com")           // substring → score 3
    let result = engine.suggestions(for: "swift", openTabs: [substring, prefix])

    let rankedTabIDs = result.compactMap { suggestion -> UUID? in
      if case let .switchToTab(id) = suggestion.kind { return id }
      return nil
    }
    XCTAssertEqual(rankedTabIDs, [prefix.id, substring.id])
  }

  // MARK: - Favorites suggestions

  private func favorite(_ title: String, _ urlString: String) -> FavoriteItem {
    FavoriteItem(id: UUID(), title: title, url: url(urlString))
  }

  func testMatchingFavoriteAppearsAfterURLActionAndBeforeTabs() {
    let fav = favorite("Swift.org", "https://swift.org")
    let openTab = tab("Swift Forums", "https://forums.swift.org")
    let result = engine.suggestions(for: "swift", openTabs: [openTab], favorites: [fav])

    XCTAssertEqual(result.count, 3)
    // "swift" has no dot, so the URL action classifies as a search — still the first row.
    switch result[0].kind {
    case .navigate, .search: break
    default: XCTFail("first should be the URL/search action")
    }
    XCTAssertEqual(result[1].kind, .favorite(url("https://swift.org")))
    XCTAssertEqual(result[2].kind, .switchToTab(tabID: openTab.id))
  }

  func testNonMatchingFavoritesExcluded() {
    let fav = favorite("Hacker News", "https://news.ycombinator.com")
    let result = engine.suggestions(for: "swift", openTabs: [], favorites: [fav])
    XCTAssertFalse(result.contains { if case .favorite = $0.kind { return true } else { return false } })
  }

  func testHistoryDeduplicatesAgainstFavorites() {
    let shared = "https://swift.org"
    let fav = favorite("Swift", shared)
    let hist = entry("Swift.org", shared)
    let result = engine.suggestions(for: "swift", openTabs: [], favorites: [fav], history: [hist])

    // The page is offered as a favorite, not duplicated as a history row.
    XCTAssertEqual(result.filter { if case .history = $0.kind { return true } else { return false } }.count, 0)
    XCTAssertEqual(result.last?.kind, .favorite(url(shared)))
  }

  // MARK: - History suggestions

  private func entry(_ title: String, _ urlString: String,
                     visitCount: Int = 1, visitedAt: Date = .distantPast) -> HistoryEntry {
    HistoryEntry(id: UUID(), title: title, url: url(urlString), visitedAt: visitedAt, visitCount: visitCount)
  }

  func testMatchingHistoryAppearsAfterURLActionAndTabs() {
    let tab = tab("Swift Forums", "https://forums.swift.org")
    let hist = entry("Swift.org", "https://swift.org")
    let result = engine.suggestions(for: "swift", openTabs: [tab], history: [hist])

    XCTAssertEqual(result.count, 3)
    // "swift" has no dot, so the URL action classifies as a search — still the first row.
    switch result[0].kind {
    case .navigate, .search: break
    default: XCTFail("first should be the URL/search action")
    }
    XCTAssertEqual(result[1].kind, .switchToTab(tabID: tab.id))
    XCTAssertEqual(result[2].kind, .history(url("https://swift.org")))
  }

  func testNonMatchingHistoryExcluded() {
    let hist = entry("Hacker News", "https://news.ycombinator.com")
    let result = engine.suggestions(for: "swift", openTabs: [], history: [hist])
    XCTAssertFalse(result.contains { if case .history = $0.kind { return true } else { return false } })
  }

  func testHistoryRankedByFrequencyThenRecency() {
    // All three are title-prefix matches (same score); frequency then recency decide the order.
    let rare = entry("Swift A", "https://a.swift.example", visitCount: 1, visitedAt: Date(timeIntervalSince1970: 300))
    let frequent = entry("Swift B", "https://b.swift.example", visitCount: 9, visitedAt: Date(timeIntervalSince1970: 100))
    let recent = entry("Swift C", "https://c.swift.example", visitCount: 1, visitedAt: Date(timeIntervalSince1970: 900))
    let result = engine.suggestions(for: "swift", openTabs: [], history: [rare, frequent, recent])

    let historyURLs = result.compactMap { suggestion -> URL? in
      if case let .history(u) = suggestion.kind { return u }
      return nil
    }
    XCTAssertEqual(historyURLs, [frequent.url, recent.url, rare.url])
  }

  func testHistoryDeduplicatesAgainstOpenTabs() {
    let shared = url("https://swift.org")
    let openTab = OpenTab(id: UUID(), title: "Swift", url: shared)
    let hist = entry("Swift.org", "https://swift.org")
    let result = engine.suggestions(for: "swift", openTabs: [openTab], history: [hist])

    // The page is offered as an open tab to switch to, not duplicated as a history row.
    XCTAssertEqual(result.filter { if case .history = $0.kind { return true } else { return false } }.count, 0)
    XCTAssertEqual(result.last?.kind, .switchToTab(tabID: openTab.id))
  }
}
