import Foundation
import XCTest
@testable import BrowserCore

@MainActor
final class TabManagerTests: XCTestCase {

  // MARK: - Init

  func testInitSeedsOneActiveTab() {
    let manager = TabManager()
    XCTAssertEqual(manager.tabs.count, 1)
    XCTAssertEqual(manager.activeTabID, manager.tabs[0].id)
    XCTAssertEqual(manager.activeTab?.id, manager.tabs[0].id)
  }

  // MARK: - newTab / select

  func testNewTabAppendsAndActivates() {
    let manager = TabManager()
    let first = manager.tabs[0]
    let created = manager.newTab()
    XCTAssertEqual(manager.tabs.map(\.id), [first.id, created.id])
    XCTAssertEqual(manager.activeTabID, created.id)
  }

  func testSelectChangesActiveTab() {
    let manager = TabManager()
    let first = manager.tabs[0]
    _ = manager.newTab() // becomes active
    manager.select(first.id)
    XCTAssertEqual(manager.activeTabID, first.id)
    XCTAssertEqual(manager.activeTab?.id, first.id)
  }

  func testSelectUnknownIdIsIgnored() {
    let manager = TabManager()
    let active = manager.activeTabID
    manager.select(UUID())
    XCTAssertEqual(manager.activeTabID, active)
  }

  // MARK: - closeTab

  func testCloseNonActiveTabKeepsActive() {
    let manager = TabManager()
    let first = manager.tabs[0]
    let second = manager.newTab()
    manager.select(first.id)
    manager.closeTab(second.id)
    XCTAssertEqual(manager.tabs.map(\.id), [first.id])
    XCTAssertEqual(manager.activeTabID, first.id)
  }

  func testCloseActiveMiddleTabSelectsRightNeighbor() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    let c = manager.newTab()
    manager.select(b.id)
    manager.closeTab(b.id)
    XCTAssertEqual(manager.tabs.map(\.id), [a.id, c.id])
    XCTAssertEqual(manager.activeTabID, c.id) // tab that shifted into b's slot
  }

  func testCloseActiveRightmostTabSelectsNewLast() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    let c = manager.newTab()
    manager.select(c.id)
    manager.closeTab(c.id)
    XCTAssertEqual(manager.tabs.map(\.id), [a.id, b.id])
    XCTAssertEqual(manager.activeTabID, b.id)
  }

  func testCloseLastTabOpensFreshTab() {
    let manager = TabManager()
    let only = manager.tabs[0]
    manager.closeTab(only.id)
    XCTAssertEqual(manager.tabs.count, 1)
    XCTAssertNotEqual(manager.tabs[0].id, only.id)
    XCTAssertEqual(manager.activeTabID, manager.tabs[0].id)
  }

  // MARK: - move

  func testMoveReordersAndPreservesActiveByIdentity() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    let c = manager.newTab()
    manager.select(a.id)
    manager.move(from: 0, to: 2)
    XCTAssertEqual(manager.tabs.map(\.id), [b.id, c.id, a.id])
    XCTAssertEqual(manager.activeTabID, a.id) // active follows the tab, not the index
  }

  func testMoveOutOfRangeIsIgnored() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    manager.move(from: 5, to: 0)
    XCTAssertEqual(manager.tabs.map(\.id), [a.id, b.id])
  }

  // MARK: - cycling

  func testSelectNextWrapsAround() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    manager.select(a.id)
    manager.selectNext()
    XCTAssertEqual(manager.activeTabID, b.id)
    manager.selectNext()
    XCTAssertEqual(manager.activeTabID, a.id) // wraps
  }

  func testSelectPreviousWrapsAround() {
    let manager = TabManager()
    let a = manager.tabs[0]
    let b = manager.newTab()
    manager.select(a.id)
    manager.selectPrevious()
    XCTAssertEqual(manager.activeTabID, b.id) // wraps to last
  }
}
