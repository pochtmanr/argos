import Foundation
import Network
import XCTest
@testable import BrowserCore

/// Tests for per-space proxy parsing, application, and persistence.
@MainActor
final class ProxyTests: XCTestCase {

  // MARK: - ProxyConfigParser

  func testParsesBareHostPortAsSocks5() {
    XCTAssertNotNil(ProxyConfigParser.configuration(from: "127.0.0.1:1080"))
  }

  func testParsesSchemesAndCredentials() {
    XCTAssertNotNil(ProxyConfigParser.configuration(from: "socks5://user:pass@host.example:1080"))
    XCTAssertNotNil(ProxyConfigParser.configuration(from: "http://host.example:8080"))
    XCTAssertNotNil(ProxyConfigParser.configuration(from: "user@host.example:1080"))
  }

  func testRejectsEmptyOrMalformedStrings() {
    XCTAssertNil(ProxyConfigParser.configuration(from: ""))
    XCTAssertNil(ProxyConfigParser.configuration(from: "   "))
    XCTAssertNil(ProxyConfigParser.configuration(from: "nohostport"))
    XCTAssertNil(ProxyConfigParser.configuration(from: "host.example:notaport"))
  }

  // MARK: - SpaceStore.setProxy

  func testSetProxyUpdatesSpaceAndRebuildsTabsPreservingIdentity() {
    let store = SpaceStore()
    let space = store.activeSpace!
    let tabIDs = space.tabManager.tabs.map(\.id)
    let activeBefore = space.tabManager.activeTabID

    store.setProxy(space.id, string: "socks5://127.0.0.1:1080", enabled: true)

    XCTAssertEqual(space.proxyConfigString, "socks5://127.0.0.1:1080")
    XCTAssertTrue(space.proxyEnabled)
    // Tabs are rebuilt (fresh WKWebViews) but keep their ids and the active selection.
    XCTAssertEqual(space.tabManager.tabs.map(\.id), tabIDs)
    XCTAssertEqual(space.tabManager.activeTabID, activeBefore)

    store.setProxy(space.id, string: nil, enabled: false)
    XCTAssertFalse(space.proxyEnabled)
    XCTAssertNil(space.proxyConfigString)
    XCTAssertEqual(space.tabManager.tabs.map(\.id), tabIDs)
  }

  // MARK: - Persistence round-trip

  func testProxyFieldsRoundTrip() throws {
    let name = "ProxyTests.\(#function)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let persistence = try SessionPersistence(inMemory: true, defaults: defaults)

    let tab = WebTab(url: URL(string: "https://a.example"), title: "A", deferLoad: true)
    let space = Space(
      name: "Proxied", colorHex: "#FF0000", icon: "globe",
      tabManager: TabManager(tabs: [tab], activeTabID: tab.id),
      proxyConfigString: "socks5://10.0.0.1:1080", proxyEnabled: true
    )
    persistence.save(SpaceStore(spaces: [space], activeSpaceID: space.id))

    let restored = try XCTUnwrap(persistence.load())
    let restoredSpace = try XCTUnwrap(restored.spaces.first)
    XCTAssertEqual(restoredSpace.proxyConfigString, "socks5://10.0.0.1:1080")
    XCTAssertTrue(restoredSpace.proxyEnabled)
  }
}
