import Foundation
import XCTest
@testable import BrowserCore

@MainActor
final class SpaceStoreTests: XCTestCase {

  // MARK: - Init

  func testInitSeedsOneActiveDefaultSpace() {
    let store = SpaceStore()
    XCTAssertEqual(store.spaces.count, 1)
    XCTAssertEqual(store.activeSpaceID, store.spaces[0].id)
    XCTAssertEqual(store.activeSpace?.id, store.spaces[0].id)
    XCTAssertFalse(store.spaces[0].name.isEmpty)
    // The seeded space's own TabManager satisfies its invariant: exactly one active tab.
    XCTAssertEqual(store.spaces[0].tabManager.tabs.count, 1)
  }

  // MARK: - Independent tabs per space (the defining property)

  func testEachSpaceHasIndependentTabManager() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let b = store.newSpace()
    XCTAssertNotIdentical(a.tabManager, b.tabManager)

    a.tabManager.newTab()
    XCTAssertEqual(a.tabManager.tabs.count, 2)
    XCTAssertEqual(b.tabManager.tabs.count, 1) // unaffected
    XCTAssertTrue(Set(a.tabManager.tabs.map(\.id)).isDisjoint(with: b.tabManager.tabs.map(\.id)))
  }

  // MARK: - newSpace / switchTo

  func testNewSpaceAppendsAndActivates() {
    let store = SpaceStore()
    let first = store.spaces[0]
    let created = store.newSpace(name: "Work", colorHex: "#FF0000", icon: "briefcase")
    XCTAssertEqual(store.spaces.map(\.id), [first.id, created.id])
    XCTAssertEqual(store.activeSpaceID, created.id)
    XCTAssertEqual(created.name, "Work")
    XCTAssertEqual(created.colorHex, "#FF0000")
    XCTAssertEqual(created.icon, "briefcase")
  }

  func testNewSpaceStartsWithItsOwnSeededTab() {
    let store = SpaceStore()
    let created = store.newSpace()
    XCTAssertEqual(created.tabManager.tabs.count, 1)
    XCTAssertEqual(created.tabManager.activeTabID, created.tabManager.tabs[0].id)
  }

  func testSwitchToChangesActiveSpace() {
    let store = SpaceStore()
    let first = store.spaces[0]
    _ = store.newSpace() // becomes active
    store.switchTo(first.id)
    XCTAssertEqual(store.activeSpaceID, first.id)
    XCTAssertEqual(store.activeSpace?.id, first.id)
  }

  func testSwitchToUnknownIdIsIgnored() {
    let store = SpaceStore()
    let active = store.activeSpaceID
    store.switchTo(UUID())
    XCTAssertEqual(store.activeSpaceID, active)
  }

  func testSwitchPreservesPerSpaceActiveTab() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let aSecondTab = a.tabManager.newTab() // a's active tab is now its second tab
    let b = store.newSpace()
    store.switchTo(b.id)
    store.switchTo(a.id)
    XCTAssertEqual(a.tabManager.activeTabID, aSecondTab.id)
  }

  // MARK: - rename / recolor / setIcon

  func testRenameUpdatesName() {
    let store = SpaceStore()
    store.rename(store.spaces[0].id, to: "Reading")
    XCTAssertEqual(store.spaces[0].name, "Reading")
  }

  func testRecolorUpdatesColor() {
    let store = SpaceStore()
    store.recolor(store.spaces[0].id, to: "#00FF00")
    XCTAssertEqual(store.spaces[0].colorHex, "#00FF00")
  }

  func testSetIconUpdatesIcon() {
    let store = SpaceStore()
    store.setIcon(store.spaces[0].id, to: "music.note")
    XCTAssertEqual(store.spaces[0].icon, "music.note")
  }

  func testMutatingUnknownIdIsIgnored() {
    let store = SpaceStore()
    let name = store.spaces[0].name
    let color = store.spaces[0].colorHex
    let icon = store.spaces[0].icon
    store.rename(UUID(), to: "x")
    store.recolor(UUID(), to: "#123456")
    store.setIcon(UUID(), to: "star")
    XCTAssertEqual(store.spaces[0].name, name)
    XCTAssertEqual(store.spaces[0].colorHex, color)
    XCTAssertEqual(store.spaces[0].icon, icon)
  }

  // MARK: - deleteSpace

  func testDeleteNonActiveSpaceKeepsActive() {
    let store = SpaceStore()
    let first = store.spaces[0]
    let second = store.newSpace()
    store.switchTo(first.id)
    store.deleteSpace(second.id)
    XCTAssertEqual(store.spaces.map(\.id), [first.id])
    XCTAssertEqual(store.activeSpaceID, first.id)
  }

  func testDeleteActiveMiddleSpaceSelectsRightNeighbor() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let b = store.newSpace()
    let c = store.newSpace()
    store.switchTo(b.id)
    store.deleteSpace(b.id)
    XCTAssertEqual(store.spaces.map(\.id), [a.id, c.id])
    XCTAssertEqual(store.activeSpaceID, c.id) // space that shifted into b's slot
  }

  func testDeleteActiveRightmostSpaceSelectsNewLast() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let b = store.newSpace()
    let c = store.newSpace()
    store.switchTo(c.id)
    store.deleteSpace(c.id)
    XCTAssertEqual(store.spaces.map(\.id), [a.id, b.id])
    XCTAssertEqual(store.activeSpaceID, b.id)
  }

  func testDeleteLastSpaceReseedsFreshDefault() {
    let store = SpaceStore()
    let only = store.spaces[0]
    store.deleteSpace(only.id)
    XCTAssertEqual(store.spaces.count, 1)
    XCTAssertNotEqual(store.spaces[0].id, only.id)
    XCTAssertEqual(store.activeSpaceID, store.spaces[0].id)
    XCTAssertFalse(store.spaces[0].name.isEmpty)
    XCTAssertEqual(store.spaces[0].tabManager.tabs.count, 1) // fresh space has its own tab
  }

  func testDeleteUnknownIdIsIgnored() {
    let store = SpaceStore()
    let ids = store.spaces.map(\.id)
    store.deleteSpace(UUID())
    XCTAssertEqual(store.spaces.map(\.id), ids)
  }

  func testDeletingSpaceReleasesItsTabManager() {
    let store = SpaceStore()
    weak var weakTabManager: TabManager?
    weak var weakTab: WebTab?
    // Scope the strong `Space` ref so only `store.spaces` retains it after the closure returns.
    let id: Space.ID = {
      let extra = store.newSpace()
      weakTabManager = extra.tabManager
      weakTab = extra.tabManager.tabs.first
      return extra.id
    }()
    XCTAssertNotNil(weakTabManager)
    XCTAssertNotNil(weakTab)

    store.deleteSpace(id)

    XCTAssertNil(weakTabManager, "deleting a space must release its TabManager (no retain cycle)")
    XCTAssertNil(weakTab, "deleting a space must release its tabs' web views")
  }

  // MARK: - moveSpace

  func testMoveReordersAndPreservesActiveByIdentity() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let b = store.newSpace()
    let c = store.newSpace()
    store.switchTo(a.id)
    store.moveSpace(from: 0, to: 2)
    XCTAssertEqual(store.spaces.map(\.id), [b.id, c.id, a.id])
    XCTAssertEqual(store.activeSpaceID, a.id) // active follows the space, not the index
  }

  func testMoveOutOfRangeIsIgnored() {
    let store = SpaceStore()
    let a = store.spaces[0]
    let b = store.newSpace()
    store.moveSpace(from: 5, to: 0)
    XCTAssertEqual(store.spaces.map(\.id), [a.id, b.id])
  }
}
