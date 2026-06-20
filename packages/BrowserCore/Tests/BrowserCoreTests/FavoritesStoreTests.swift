import Foundation
import XCTest
@testable import BrowserCore

@MainActor
final class FavoritesStoreTests: XCTestCase {

  /// Fresh in-memory favorites store, isolated per test.
  private func makeStore() throws -> FavoritesStore {
    try FavoritesStore(inMemory: true)
  }

  private func url(_ string: String) -> URL { URL(string: string)! }

  private let spaceA = UUID()
  private let spaceB = UUID()

  // MARK: - Add & order

  func testAddAppendsAndAssignsIncrementingOrder() throws {
    let store = try makeStore()
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    store.add(url: url("https://b.example"), title: "B", spaceID: spaceA)

    let all = store.all(spaceID: spaceA)
    XCTAssertEqual(all.map(\.title), ["A", "B"])
    XCTAssertEqual(all.map(\.order), [0, 1])
  }

  // MARK: - De-dupe

  func testAddingSameURLTwiceDeDupes() throws {
    let store = try makeStore()
    let first = store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    let second = store.add(url: url("https://a.example"), title: "A again", spaceID: spaceA)

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(store.all(spaceID: spaceA).count, 1)
  }

  func testDeDupeIgnoresTrailingSlash() throws {
    let store = try makeStore()
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    store.add(url: url("https://a.example/"), title: "A slash", spaceID: spaceA)

    XCTAssertEqual(store.all(spaceID: spaceA).count, 1)
  }

  func testContainsReflectsMembership() throws {
    let store = try makeStore()
    XCTAssertFalse(store.contains(url: url("https://a.example"), in: spaceA))
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    XCTAssertTrue(store.contains(url: url("https://a.example/"), in: spaceA))
    XCTAssertFalse(store.contains(url: url("https://a.example"), in: spaceB))
  }

  // MARK: - Remove

  func testRemoveDeletesAndCompactsOrder() throws {
    let store = try makeStore()
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    let b = store.add(url: url("https://b.example"), title: "B", spaceID: spaceA)
    store.add(url: url("https://c.example"), title: "C", spaceID: spaceA)

    store.remove(b)

    let all = store.all(spaceID: spaceA)
    XCTAssertEqual(all.map(\.title), ["A", "C"])
    XCTAssertEqual(all.map(\.order), [0, 1], "orders stay dense after a removal")
  }

  // MARK: - Move

  func testMoveReordersWithinSpace() throws {
    let store = try makeStore()
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    store.add(url: url("https://b.example"), title: "B", spaceID: spaceA)
    store.add(url: url("https://c.example"), title: "C", spaceID: spaceA)

    // Move C (index 2) to the front (index 0).
    store.move(from: 2, to: 0, in: spaceA)

    let all = store.all(spaceID: spaceA)
    XCTAssertEqual(all.map(\.title), ["C", "A", "B"])
    XCTAssertEqual(all.map(\.order), [0, 1, 2])
  }

  // MARK: - Per-Space isolation

  func testFavoritesAreScopedPerSpace() throws {
    let store = try makeStore()
    store.add(url: url("https://a.example"), title: "A", spaceID: spaceA)
    store.add(url: url("https://b.example"), title: "B", spaceID: spaceB)

    XCTAssertEqual(store.all(spaceID: spaceA).map(\.title), ["A"])
    XCTAssertEqual(store.all(spaceID: spaceB).map(\.title), ["B"])
    // Same URL can be a favorite in two Spaces independently, each with its own order 0.
    store.add(url: url("https://a.example"), title: "A in B", spaceID: spaceB)
    XCTAssertEqual(store.all(spaceID: spaceB).map(\.order), [0, 1])
  }

  // MARK: - Toggle (⌘D)

  func testToggleAddsThenRemoves() throws {
    let store = try makeStore()
    let target = url("https://a.example")

    store.toggle(url: target, title: "A", spaceID: spaceA)
    XCTAssertTrue(store.contains(url: target, in: spaceA))

    store.toggle(url: target, title: "A", spaceID: spaceA)
    XCTAssertFalse(store.contains(url: target, in: spaceA))
    XCTAssertTrue(store.all(spaceID: spaceA).isEmpty)
  }
}
