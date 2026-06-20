import Foundation
import XCTest
@testable import BrowserCore

@MainActor
final class HistoryStoreTests: XCTestCase {
  private func makeStore() throws -> HistoryStore {
    try HistoryStore(inMemory: true)
  }

  private func url(_ string: String) -> URL { URL(string: string)! }
  private func date(_ t: TimeInterval) -> Date { Date(timeIntervalSince1970: t) }

  // MARK: - Recording

  func testRecordInsertsNewEntry() throws {
    let store = try makeStore()
    store.record(url: url("https://a.example"), title: "A", now: date(1000))

    XCTAssertEqual(store.entries.count, 1)
    let entry = try XCTUnwrap(store.entries.first)
    XCTAssertEqual(entry.url, url("https://a.example"))
    XCTAssertEqual(entry.title, "A")
    XCTAssertEqual(entry.visitCount, 1)
    XCTAssertEqual(entry.visitedAt, date(1000))
  }

  func testNonHTTPURLIsIgnored() throws {
    let store = try makeStore()
    store.record(url: url("file:///tmp/page.html"), title: "Local", now: date(1000))
    store.record(url: url("about:blank"), title: "Blank", now: date(1000))
    XCTAssertTrue(store.entries.isEmpty)
  }

  func testRevisitBumpsVisitCountAndRefreshesTimestampAndTitle() throws {
    let store = try makeStore()
    let page = url("https://a.example")
    store.record(url: page, title: "A", now: date(1000))
    store.record(url: page, title: "A — updated", now: date(1100))  // well beyond the dedupe window

    XCTAssertEqual(store.entries.count, 1)
    let entry = try XCTUnwrap(store.entries.first)
    XCTAssertEqual(entry.visitCount, 2)
    XCTAssertEqual(entry.visitedAt, date(1100))
    XCTAssertEqual(entry.title, "A — updated")
  }

  func testRapidRepeatDoesNotBumpVisitCount() throws {
    let store = try makeStore()
    let page = url("https://a.example")
    store.record(url: page, title: "A", now: date(1000))
    store.record(url: page, title: "A", now: date(1001))  // within the 2s dedupe window

    XCTAssertEqual(store.entries.count, 1)
    let entry = try XCTUnwrap(store.entries.first)
    XCTAssertEqual(entry.visitCount, 1)
    XCTAssertEqual(entry.visitedAt, date(1001))  // timestamp still refreshed
  }

  // MARK: - Queries

  func testSearchFiltersByTitleAndURL() throws {
    let store = try makeStore()
    store.record(url: url("https://apple.com"), title: "Apple", now: date(1000))
    store.record(url: url("https://swift.org"), title: "The Swift Language", now: date(1001))

    XCTAssertEqual(store.search("apple").map(\.url), [url("https://apple.com")])
    XCTAssertEqual(store.search("swift.org").map(\.url), [url("https://swift.org")])
    XCTAssertEqual(store.search("language").map(\.url), [url("https://swift.org")])
    XCTAssertEqual(Set(store.search("").map(\.url)),
                   [url("https://apple.com"), url("https://swift.org")])
  }

  func testRecentReturnsMostRecentFirstCapped() throws {
    let store = try makeStore()
    store.record(url: url("https://a.example"), title: "A", now: date(100))
    store.record(url: url("https://b.example"), title: "B", now: date(200))
    store.record(url: url("https://c.example"), title: "C", now: date(300))

    XCTAssertEqual(store.recent(limit: 2).map(\.url),
                   [url("https://c.example"), url("https://b.example")])
    XCTAssertTrue(store.recent(limit: 0).isEmpty)
  }

  // MARK: - Deletion

  func testDeleteRemovesEntry() throws {
    let store = try makeStore()
    store.record(url: url("https://a.example"), title: "A", now: date(100))
    store.record(url: url("https://b.example"), title: "B", now: date(200))

    let toDelete = try XCTUnwrap(store.entries.first { $0.url == url("https://a.example") })
    store.delete(toDelete)

    XCTAssertEqual(store.entries.map(\.url), [url("https://b.example")])
  }

  func testClearSinceRemovesNewerKeepsOlder() throws {
    let store = try makeStore()
    store.record(url: url("https://old.example"), title: "Old", now: date(100))
    store.record(url: url("https://new.example"), title: "New", now: date(1000))

    store.clear(since: date(500))

    XCTAssertEqual(store.entries.map(\.url), [url("https://old.example")])
  }

  func testClearAllEmpties() throws {
    let store = try makeStore()
    store.record(url: url("https://a.example"), title: "A", now: date(100))
    store.record(url: url("https://b.example"), title: "B", now: date(200))

    store.clear(since: nil)

    XCTAssertTrue(store.entries.isEmpty)
  }
}
