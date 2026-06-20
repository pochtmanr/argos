import Foundation
import XCTest
@testable import BrowserCore

/// Tests for Prompt 11 auto-archive: the `TabManager.archiveStaleTabs` decision, restore/delete, the
/// `select` recency stamp, per-Space scoping via `SpaceStore`, and the persistence round-trip of
/// archived records.
@MainActor
final class TabArchiveTests: XCTestCase {

  /// Fixed reference instant so staleness math is deterministic.
  private let now = Date(timeIntervalSince1970: 1_000_000)
  /// One hour, the threshold used throughout.
  private let hour: TimeInterval = 3600

  /// Builds a tab with a controlled `lastAccessed`; `deferLoad` keeps tests off the network.
  private func makeTab(_ url: String, _ title: String = "", pinned: Bool = false, accessed: Date) -> WebTab {
    WebTab(url: URL(string: url), title: title, isPinned: pinned, lastAccessed: accessed, deferLoad: true)
  }

  // MARK: - archiveStaleTabs

  func testArchivesStaleUnpinnedNonActiveTab() {
    let active = makeTab("https://active.example", "Active", accessed: now)
    let stale = makeTab("https://stale.example", "Stale", accessed: now.addingTimeInterval(-2 * hour))
    let manager = TabManager(tabs: [active, stale], activeTabID: active.id)

    let archived = manager.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertEqual(archived.map(\.id), [stale.id])
    XCTAssertEqual(manager.tabs.map(\.id), [active.id], "stale tab leaves the live list")
    XCTAssertEqual(manager.archivedTabs.map(\.id), [stale.id])
    // Saved fields survive onto the archived record.
    let record = manager.archivedTabs[0]
    XCTAssertEqual(record.url, URL(string: "https://stale.example"))
    XCTAssertEqual(record.title, "Stale")
    XCTAssertEqual(record.lastAccessed, now.addingTimeInterval(-2 * hour))
  }

  func testDoesNotArchivePinnedTab() {
    let active = makeTab("https://active.example", accessed: now)
    let pinnedStale = makeTab("https://pinned.example", pinned: true, accessed: now.addingTimeInterval(-5 * hour))
    let manager = TabManager(tabs: [active, pinnedStale], activeTabID: active.id)

    let archived = manager.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertTrue(archived.isEmpty)
    XCTAssertEqual(manager.tabs.map(\.id), [active.id, pinnedStale.id], "pinned tab is exempt")
    XCTAssertTrue(manager.archivedTabs.isEmpty)
  }

  func testDoesNotArchiveActiveTab() {
    let active = makeTab("https://active.example", accessed: now.addingTimeInterval(-5 * hour))
    let other = makeTab("https://other.example", accessed: now)
    let manager = TabManager(tabs: [active, other], activeTabID: active.id)

    manager.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertTrue(manager.tabs.contains { $0.id == active.id }, "the active tab is never archived")
    XCTAssertTrue(manager.archivedTabs.isEmpty, "the fresh non-active tab isn't stale either")
    XCTAssertFalse(manager.tabs.isEmpty, "the manager never empties")
  }

  func testThresholdBoundaryIsNotArchivedButJustOverIs() {
    let active = makeTab("https://active.example", accessed: now)
    let boundary = makeTab("https://boundary.example", accessed: now.addingTimeInterval(-hour))
    let justOver = makeTab("https://over.example", accessed: now.addingTimeInterval(-hour - 1))
    let manager = TabManager(tabs: [active, boundary, justOver], activeTabID: active.id)

    let archived = manager.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertEqual(archived.map(\.id), [justOver.id], "exactly-at-threshold stays; strictly-over archives")
    XCTAssertTrue(manager.tabs.contains { $0.id == boundary.id })
  }

  func testNoStaleTabsLeavesArchiveUntouched() {
    let active = makeTab("https://active.example", accessed: now)
    let fresh = makeTab("https://fresh.example", accessed: now.addingTimeInterval(-60))
    let manager = TabManager(tabs: [active, fresh], activeTabID: active.id)

    let archived = manager.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertTrue(archived.isEmpty)
    XCTAssertEqual(manager.tabs.count, 2)
    XCTAssertTrue(manager.archivedTabs.isEmpty)
  }

  // MARK: - restore / delete

  func testRestoreRecreatesLiveTabAndActivatesIt() throws {
    let active = makeTab("https://active.example", accessed: now)
    // Explicit path so the live web view's URL normalization (which would append a trailing slash to a
    // bare host) doesn't make the round-tripped URL differ from the literal we assert against.
    let stale = makeTab("https://stale.example/page", "Stale", accessed: now.addingTimeInterval(-2 * hour))
    let manager = TabManager(tabs: [active, stale], activeTabID: active.id)
    manager.archiveStaleTabs(now: now, threshold: hour)

    let restoredTab = try XCTUnwrap(manager.restoreArchived(stale.id))

    XCTAssertEqual(restoredTab.id, stale.id)
    XCTAssertEqual(restoredTab.url, URL(string: "https://stale.example/page"))
    XCTAssertEqual(restoredTab.title, "Stale")
    XCTAssertTrue(manager.archivedTabs.isEmpty, "restored tab leaves the archive")
    XCTAssertTrue(manager.tabs.contains { $0.id == stale.id }, "restored tab rejoins the live list")
    XCTAssertEqual(manager.activeTabID, stale.id, "restored tab becomes active")
  }

  func testRestoreUnknownIdReturnsNil() {
    let manager = TabManager()
    XCTAssertNil(manager.restoreArchived(UUID()))
  }

  func testDeleteArchivedRemovesPermanently() {
    let active = makeTab("https://active.example", accessed: now)
    let stale = makeTab("https://stale.example", accessed: now.addingTimeInterval(-2 * hour))
    let manager = TabManager(tabs: [active, stale], activeTabID: active.id)
    manager.archiveStaleTabs(now: now, threshold: hour)
    XCTAssertEqual(manager.archivedTabs.count, 1)

    manager.deleteArchived(stale.id)

    XCTAssertTrue(manager.archivedTabs.isEmpty)
    XCTAssertFalse(manager.tabs.contains { $0.id == stale.id }, "delete does not bring it back as a live tab")
  }

  // MARK: - select stamps recency

  func testSelectUpdatesLastAccessed() {
    let a = makeTab("https://a.example", accessed: Date(timeIntervalSince1970: 1))
    let b = makeTab("https://b.example", accessed: Date(timeIntervalSince1970: 1))
    let manager = TabManager(tabs: [a, b], activeTabID: a.id)
    let before = b.lastAccessed

    manager.select(b.id)

    XCTAssertGreaterThan(b.lastAccessed, before, "selecting a tab stamps it as just-used")
  }

  // MARK: - per-Space scoping

  func testSpaceStoreArchivesPerSpaceAndExemptsEachActiveTab() {
    let a1 = makeTab("https://a1.example", accessed: now)                              // active in A
    let a2 = makeTab("https://a2.example", accessed: now.addingTimeInterval(-3 * hour)) // stale in A
    let spaceA = Space(name: "A", colorHex: "#111111", icon: "1.square",
                       tabManager: TabManager(tabs: [a1, a2], activeTabID: a1.id))

    let b1 = makeTab("https://b1.example", accessed: now.addingTimeInterval(-3 * hour)) // active but stale in B
    let b2 = makeTab("https://b2.example", accessed: now)                              // fresh in B
    let spaceB = Space(name: "B", colorHex: "#222222", icon: "2.square",
                       tabManager: TabManager(tabs: [b1, b2], activeTabID: b1.id))

    let store = SpaceStore(spaces: [spaceA, spaceB], activeSpaceID: spaceA.id)

    store.archiveStaleTabs(now: now, threshold: hour)

    XCTAssertEqual(spaceA.tabManager.archivedTabs.map(\.id), [a2.id], "A archives only its stale non-active tab")
    XCTAssertEqual(spaceA.tabManager.tabs.map(\.id), [a1.id])
    XCTAssertTrue(spaceB.tabManager.archivedTabs.isEmpty, "B's stale tab is its active tab, so exempt")
    XCTAssertEqual(spaceB.tabManager.tabs.map(\.id), [b1.id, b2.id])
  }

  // MARK: - persistence round-trip

  func testArchivedTabsSurviveSaveAndLoad() throws {
    let suite = "TabArchiveTests.roundtrip"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let persistence = try SessionPersistence(inMemory: true, defaults: defaults)

    let active = makeTab("https://active.example", "Active", accessed: now)
    let stale = makeTab("https://stale.example", "Stale", accessed: now.addingTimeInterval(-3 * hour))
    let space = Space(name: "Work", colorHex: "#FF0000", icon: "briefcase",
                      tabManager: TabManager(tabs: [active, stale], activeTabID: active.id))
    let store = SpaceStore(spaces: [space], activeSpaceID: space.id)

    space.tabManager.archiveStaleTabs(now: now, threshold: hour)
    XCTAssertEqual(space.tabManager.archivedTabs.map(\.id), [stale.id])

    persistence.save(store)
    let restored = try XCTUnwrap(persistence.load())
    let manager = try XCTUnwrap(restored.spaces.first?.tabManager)

    XCTAssertEqual(manager.tabs.map(\.id), [active.id], "only the open tab restores as a live tab")
    XCTAssertEqual(manager.archivedTabs.map(\.id), [stale.id], "archived tab restores as a record")
    let record = try XCTUnwrap(manager.archivedTabs.first)
    XCTAssertEqual(record.url, URL(string: "https://stale.example"))
    XCTAssertEqual(record.title, "Stale")
    XCTAssertEqual(record.lastAccessed, now.addingTimeInterval(-3 * hour))
  }
}
