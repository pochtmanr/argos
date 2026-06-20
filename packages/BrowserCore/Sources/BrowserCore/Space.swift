import Foundation
import Observation
import WebKit

/// A named, colored container of tabs — the app's "Space" (Work, Personal, a project).
///
/// A Space owns its own `TabManager`, so its tabs and active tab are fully independent of every
/// other Space. Tab ownership is therefore unambiguous: **a tab lives in exactly one Space's
/// `TabManager`.** This type is a platform-agnostic value-holder — it stores a `colorHex` string
/// and an SF Symbol `icon` name rather than any UI color/image, so it stays serializable for the
/// persistence layer (Prompt 06). The hosting app decides what a Space's tabs load.
@Observable
@MainActor
public final class Space: Identifiable {
  /// Stable identity for the lifetime of the space. `@ObservationIgnored` because it never changes.
  /// Assigned in `init` so a restored space can keep the id it was persisted under.
  @ObservationIgnored
  public let id: UUID

  /// User-facing name, e.g. "Work".
  public var name: String
  /// Accent color as a hex string (e.g. `"#3B82F6"`). The UI maps this to a concrete color.
  public var colorHex: String
  /// SF Symbol name for the space's glyph, e.g. `"briefcase"`.
  public var icon: String

  /// Whether this is the **Personal** profile — the main user's real browsing identity, which is *not*
  /// one of the isolated Spaces. The Personal profile intentionally uses the shared `.default()` data
  /// store (so existing logins are available) and is protected from deletion. Every other Space is an
  /// isolated identity with its own per-space store. `@ObservationIgnored`: fixed for the space's life.
  @ObservationIgnored
  public let isPersonal: Bool

  /// The raw proxy string the user pasted for this space (e.g. `socks5://host:1080`), or `nil` for
  /// none. Persisted; the active routing is derived from this + ``proxyEnabled`` (see ``dataStore``).
  public var proxyConfigString: String?
  /// Whether this space currently routes its traffic through ``proxyConfigString``. Persisted.
  public var proxyEnabled: Bool

  /// The space's own tabs and active tab. `@ObservationIgnored` like `WebTab.webView`: the
  /// reference never changes, and its contents are observed through the `TabManager` itself.
  @ObservationIgnored
  public let tabManager: TabManager

  /// The website data store backing this space's `WKWebView`s — `.default()` when no proxy is active,
  /// or a dedicated per-space store carrying the proxy when one is set. Treated as a profile boundary:
  /// every tab in the space shares it. Rebuilt by ``updateProxy(string:enabled:)`` when the proxy
  /// changes. `@ObservationIgnored` because it's plumbing, not observable view state.
  @ObservationIgnored
  public private(set) var dataStore: WKWebsiteDataStore

  /// Creates a space. `tabManager` defaults to a fresh `TabManager`, which seeds one blank tab, so
  /// a new space is immediately usable. `id` defaults to a fresh `UUID`; session restore passes the
  /// persisted id (plus any saved proxy) so the space survives relaunch.
  public init(
    id: UUID = UUID(),
    name: String,
    colorHex: String,
    icon: String,
    isPersonal: Bool = false,
    tabManager: TabManager = TabManager(),
    proxyConfigString: String? = nil,
    proxyEnabled: Bool = false
  ) {
    self.id = id
    self.name = name
    self.colorHex = colorHex
    self.icon = icon
    self.isPersonal = isPersonal
    self.proxyConfigString = proxyConfigString
    self.proxyEnabled = proxyEnabled
    self.tabManager = tabManager
    self.dataStore = Self.makeDataStore(id: id, isPersonal: isPersonal, proxyString: proxyConfigString, enabled: proxyEnabled)
    // Every tab this space's manager creates picks up the space's data store (and thus its proxy).
    tabManager.webViewConfigurator = { [weak self] in
      self?.webViewConfiguration() ?? WKWebViewConfiguration()
    }
    // An isolated space's store is non-default, but its seeded/restored tabs were built with the
    // default store (the configurator above wasn't set yet); re-host them onto this space's store so
    // their cookies/logins are actually isolated. Personal uses `.default()`, so no rebuild is needed.
    // `rebuildWebViews` preserves each tab's deferred-load state, so lazy session restore is unaffected.
    if !isPersonal { tabManager.rebuildWebViews() }
  }

  /// A `WKWebViewConfiguration` bound to this space's ``dataStore``. ``TabManager`` calls this for
  /// every tab it creates so the whole space shares one (optionally proxied) store.
  public func webViewConfiguration() -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = dataStore
    return configuration
  }

  /// Updates this space's proxy, rebuilds the backing ``dataStore``, and re-hosts the space's tabs so
  /// the new route takes effect immediately (each tab reloads through the new store).
  public func updateProxy(string: String?, enabled: Bool) {
    proxyConfigString = string
    proxyEnabled = enabled
    dataStore = Self.makeDataStore(id: id, isPersonal: isPersonal, proxyString: string, enabled: enabled)
    tabManager.rebuildWebViews()
  }

  /// Clones the cookies of `other` into this space's data store. Used by `SpaceStore.duplicateSpace`
  /// to carry logged-in sessions into a duplicate. **Only cookies clone across `WKWebsiteDataStore`s** —
  /// localStorage / IndexedDB / sessionStorage have no cross-store copy API, so sites that keep their
  /// session in those (rather than cookies) may still require a fresh login in the duplicate.
  public func importCookies(from other: Space) async {
    let source = other.dataStore.httpCookieStore
    let destination = dataStore.httpCookieStore
    for cookie in await source.allCookies() {
      await destination.setCookie(cookie)
    }
  }

  /// Builds the data store backing this space's web views.
  ///
  /// The **Personal** profile uses the shared `.default()` store — it is the main user's real identity,
  /// so its existing cookies/logins must stay available. Every other space gets a dedicated persistent
  /// store keyed by its id, so it is an isolated identity that starts with **no accounts logged in**;
  /// a parsed proxy (when enabled) is attached on top. The store is keyed by the space id so the same
  /// space keeps its own cookies/logins across launches (profile isolation).
  private static func makeDataStore(id: UUID, isPersonal: Bool, proxyString: String?, enabled: Bool) -> WKWebsiteDataStore {
    guard !isPersonal else { return .default() }
    let store = WKWebsiteDataStore(forIdentifier: id)
    if enabled,
       let proxyString,
       let configuration = ProxyConfigParser.configuration(from: proxyString) {
      store.proxyConfigurations = [configuration]
    }
    return store
  }
}
