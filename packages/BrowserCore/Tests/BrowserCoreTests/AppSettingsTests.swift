import Foundation
import XCTest
@testable import BrowserCore

/// Tests for the Prompt 13 `AppSettings` store: defaults when unset, the `UserDefaults` persistence
/// round-trip, `homeURL` parsing + fallback, and the search-engine preset list. Each test uses a
/// throwaway `UserDefaults` suite so the standard domain is never touched.
@MainActor
final class AppSettingsTests: XCTestCase {

  /// A fresh, isolated defaults suite per test (named by the test so suites don't collide), wiped on
  /// teardown so state never leaks between runs.
  private var suiteName = ""
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "AppSettingsTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testDefaultsWhenUnset() {
    let settings = AppSettings(defaults: defaults)

    XCTAssertEqual(settings.searchTemplate, AppSettings.defaultSearchTemplate)
    XCTAssertEqual(settings.homeURLString, AppSettings.defaultHomeURLString)
    XCTAssertEqual(settings.restoreOnLaunch, AppSettings.defaultRestoreOnLaunch)
    XCTAssertEqual(settings.sidebarIdealWidth, AppSettings.defaultSidebarIdealWidth)
  }

  func testPersistsAcrossInstances() {
    do {
      let settings = AppSettings(defaults: defaults)
      settings.searchTemplate = "https://duckduckgo.com/?q="
      settings.homeURLString = "https://example.com"
      settings.restoreOnLaunch = false
      settings.sidebarIdealWidth = 300
    }

    // A new instance over the same suite reads the persisted values, not the defaults.
    let reloaded = AppSettings(defaults: defaults)
    XCTAssertEqual(reloaded.searchTemplate, "https://duckduckgo.com/?q=")
    XCTAssertEqual(reloaded.homeURLString, "https://example.com")
    XCTAssertFalse(reloaded.restoreOnLaunch)
    XCTAssertEqual(reloaded.sidebarIdealWidth, 300)
  }

  func testRestoreOnLaunchPersistsFalse() {
    // `Bool` needs `object(forKey:)` (not `bool(forKey:)`) so a stored `false` isn't mistaken for unset.
    AppSettings(defaults: defaults).restoreOnLaunch = false
    XCTAssertFalse(AppSettings(defaults: defaults).restoreOnLaunch)
  }

  func testHomeURLParsesValidString() {
    let settings = AppSettings(defaults: defaults)
    settings.homeURLString = "https://news.ycombinator.com"
    XCTAssertEqual(settings.homeURL, URL(string: "https://news.ycombinator.com"))
  }

  func testHomeURLFallsBackWhenEmpty() {
    let settings = AppSettings(defaults: defaults)
    settings.homeURLString = "   "
    XCTAssertEqual(settings.homeURL, URL(string: AppSettings.defaultHomeURLString))
  }

  func testHomeURLFallsBackWhenSchemeless() {
    let settings = AppSettings(defaults: defaults)
    settings.homeURLString = "not a url"
    XCTAssertEqual(settings.homeURL, URL(string: AppSettings.defaultHomeURLString))
  }

  func testSearchEnginePresetsAreUsableTemplates() {
    XCTAssertFalse(AppSettings.searchEngines.isEmpty)
    // The default engine's template must appear in the preset list so the Settings picker can show it
    // as the current selection.
    XCTAssertTrue(AppSettings.searchEngines.contains { $0.template == AppSettings.defaultSearchTemplate })
    // Every preset resolves a query through URLBarParser to a real search URL containing the term.
    for engine in AppSettings.searchEngines {
      let parser = URLBarParser(searchTemplate: engine.template)
      guard case let .search(url) = parser.classify("swift testing") else {
        return XCTFail("\(engine.name) should classify a phrase as a search")
      }
      XCTAssertTrue(url.absoluteString.contains("swift"), "\(engine.name) search URL should carry the query")
    }
  }
}
