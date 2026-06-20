import Foundation
import XCTest
@testable import BrowserCore

/// Round-trip tests for the SwiftData persistence layer. Each test uses an **in-memory** store (so
/// SwiftData state never leaks between tests or to disk) plus a per-test `UserDefaults` suite for the
/// top-level active-space pointer.
@MainActor
final class SessionPersistenceTests: XCTestCase {

  /// Fresh in-memory persistence with an isolated defaults suite, keyed off the calling test.
  private func makePersistence(_ suite: String = #function) throws -> SessionPersistence {
    let name = "SessionPersistenceTests.\(suite)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return try SessionPersistence(inMemory: true, defaults: defaults)
  }

  /// Builds a live `SpaceStore` from plain data using the restore initializers, so tests control
  /// every persisted field deterministically (no async navigation needed).
  private func makeTab(_ url: String, _ title: String, pinned: Bool = false, accessed: Date = Date(timeIntervalSince1970: 1000)) -> WebTab {
    WebTab(url: URL(string: url), title: title, isPinned: pinned, lastAccessed: accessed, deferLoad: true)
  }

  // MARK: - Empty store

  func testLoadOnEmptyStoreReturnsNil() throws {
    let persistence = try makePersistence()
    XCTAssertNil(persistence.load(), "a never-written store should load as nil so the app seeds a default")
  }

  // MARK: - Round-trip

  func testSaveThenLoadRoundTripsSpacesAndTabs() throws {
    let persistence = try makePersistence()

    let tabA1 = makeTab("https://a.example/1", "A One", pinned: true, accessed: Date(timeIntervalSince1970: 111))
    let tabA2 = makeTab("https://a.example/2", "A Two")
    let spaceA = Space(
      name: "Work", colorHex: "#FF0000", icon: "briefcase",
      tabManager: TabManager(tabs: [tabA1, tabA2], activeTabID: tabA2.id)
    )
    let tabB1 = makeTab("https://b.example/1", "B One")
    let spaceB = Space(
      name: "Personal", colorHex: "#00FF00", icon: "house",
      tabManager: TabManager(tabs: [tabB1], activeTabID: tabB1.id)
    )
    let store = SpaceStore(spaces: [spaceA, spaceB], activeSpaceID: spaceB.id)

    persistence.save(store)
    let restored = try XCTUnwrap(persistence.load())

    // Spaces: identity, order, and metadata.
    XCTAssertEqual(restored.spaces.map(\.id), [spaceA.id, spaceB.id])
    XCTAssertEqual(restored.spaces.map(\.name), ["Work", "Personal"])
    XCTAssertEqual(restored.spaces.map(\.colorHex), ["#FF0000", "#00FF00"])
    XCTAssertEqual(restored.spaces.map(\.icon), ["briefcase", "house"])
    XCTAssertEqual(restored.activeSpaceID, spaceB.id)

    // Tabs of space A: identity, order, and every persisted field.
    let restoredA = try XCTUnwrap(restored.spaces.first { $0.id == spaceA.id })
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.id), [tabA1.id, tabA2.id])
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.url), [URL(string: "https://a.example/1"), URL(string: "https://a.example/2")])
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.title), ["A One", "A Two"])
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.isPinned), [true, false])
    XCTAssertEqual(restoredA.tabManager.tabs[0].lastAccessed, Date(timeIntervalSince1970: 111))
    XCTAssertEqual(restoredA.tabManager.activeTabID, tabA2.id, "per-space active tab is restored")
  }

  // MARK: - Reordering

  func testReorderingSpacesAndTabsSurvivesReload() throws {
    let persistence = try makePersistence()

    let t1 = makeTab("https://x/1", "1")
    let t2 = makeTab("https://x/2", "2")
    let t3 = makeTab("https://x/3", "3")
    let a = Space(name: "A", colorHex: "#111111", icon: "1.square", tabManager: TabManager(tabs: [t1, t2, t3], activeTabID: t1.id))
    let b = Space(name: "B", colorHex: "#222222", icon: "2.square")
    let c = Space(name: "C", colorHex: "#333333", icon: "3.square")
    let store = SpaceStore(spaces: [a, b, c], activeSpaceID: a.id)
    persistence.save(store)

    // Reorder both levels, then persist the new arrangement.
    store.moveSpace(from: 0, to: 2)               // [B, C, A]
    a.tabManager.move(from: 0, to: 2)             // A's tabs -> [2, 3, 1]
    persistence.save(store)

    let restored = try XCTUnwrap(persistence.load())
    XCTAssertEqual(restored.spaces.map(\.id), [b.id, c.id, a.id], "space order survives")
    let restoredA = try XCTUnwrap(restored.spaces.first { $0.id == a.id })
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.id), [t2.id, t3.id, t1.id], "tab order survives")
  }

  // MARK: - Deletion reconciliation

  func testSaveDeletesRemovedSpacesAndTabs() throws {
    let persistence = try makePersistence()

    let t1 = makeTab("https://y/1", "1")
    let t2 = makeTab("https://y/2", "2")
    let a = Space(name: "A", colorHex: "#111111", icon: "a.square", tabManager: TabManager(tabs: [t1, t2], activeTabID: t1.id))
    let b = Space(name: "B", colorHex: "#222222", icon: "b.square")
    let store = SpaceStore(spaces: [a, b], activeSpaceID: a.id)
    persistence.save(store)

    // Drop a tab and a space, then re-save.
    a.tabManager.closeTab(t2.id)
    store.deleteSpace(b.id)
    persistence.save(store)

    let restored = try XCTUnwrap(persistence.load())
    XCTAssertEqual(restored.spaces.map(\.id), [a.id], "deleted space is gone")
    let restoredA = try XCTUnwrap(restored.spaces.first)
    XCTAssertEqual(restoredA.tabManager.tabs.map(\.id), [t1.id], "deleted tab is gone")
  }

  // MARK: - Reset

  func testResetClearsTheStore() throws {
    let persistence = try makePersistence()
    let tab = makeTab("https://z/1", "Z")
    let space = Space(name: "Z", colorHex: "#000000", icon: "z.square", tabManager: TabManager(tabs: [tab], activeTabID: tab.id))
    persistence.save(SpaceStore(spaces: [space], activeSpaceID: space.id))
    XCTAssertNotNil(persistence.load())

    persistence.reset()
    XCTAssertNil(persistence.load(), "reset wipes the store so a fresh default is seeded")
  }

  // MARK: - Restore initializers

  func testWebTabRestoreInitPreservesIdAndSeedsDisplayValues() {
    let id = UUID()
    let tab = WebTab(id: id, url: URL(string: "https://example.com"), title: "Example", isPinned: true, lastAccessed: Date(timeIntervalSince1970: 42), deferLoad: true)
    XCTAssertEqual(tab.id, id)
    XCTAssertEqual(tab.url, URL(string: "https://example.com"), "deferred tab shows its saved URL before loading")
    XCTAssertEqual(tab.title, "Example")
    XCTAssertTrue(tab.isPinned)
    XCTAssertEqual(tab.lastAccessed, Date(timeIntervalSince1970: 42))
  }

  func testSpaceRestoreInitPreservesId() {
    let id = UUID()
    let space = Space(id: id, name: "S", colorHex: "#123456", icon: "star")
    XCTAssertEqual(space.id, id)
  }

  func testStoreRestoreInitFallsBackToFirstSpaceForUnknownActive() {
    let a = Space(name: "A", colorHex: "#111111", icon: "a.square")
    let b = Space(name: "B", colorHex: "#222222", icon: "b.square")
    let store = SpaceStore(spaces: [a, b], activeSpaceID: UUID())
    XCTAssertEqual(store.activeSpaceID, a.id, "an unknown active id falls back to the first space")
  }
}
