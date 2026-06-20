import Foundation
import Observation
import WebKit

/// Owns a single `WKWebView` and is the single source of truth for its navigation state.
///
/// State is driven by KVO on the web view (`estimatedProgress`, `title`, `url`, `canGoBack`,
/// `canGoForward`) plus `WKNavigationDelegate` callbacks for load lifecycle. This type is
/// platform-agnostic so it can back both the macOS and iOS UIs.
@Observable
@MainActor
public final class WebTab: Identifiable {
  /// Stable identity for the lifetime of the tab. `@ObservationIgnored` because it never changes,
  /// so it is not observable state — like `webView` below. Assigned in `init` so a restored tab can
  /// keep the id it was persisted under (and stay matchable to `TabManager.activeTabID`).
  @ObservationIgnored
  public let id: UUID

  /// The current page URL, kept in sync via KVO.
  public private(set) var url: URL?
  /// The current page title, kept in sync via KVO.
  public private(set) var title: String = ""
  /// The best favicon URL for the current page, resolved after each committed navigation. `nil` until
  /// a page with a discoverable icon loads (UIs fall back to a placeholder glyph). Updated on the main
  /// actor from ``updateFavicon()``.
  public private(set) var faviconURL: URL?
  /// Load progress in `0...1`, kept in sync via KVO.
  public private(set) var estimatedProgress: Double = 0
  /// Whether a navigation is in flight (driven by the navigation delegate).
  public private(set) var isLoading: Bool = false
  /// Whether the back list is non-empty.
  public private(set) var canGoBack: Bool = false
  /// Whether the forward list is non-empty.
  public private(set) var canGoForward: Bool = false

  /// Whether the user pinned this tab. Persisted now to power pinned tabs (Prompt 09); no UI yet.
  public var isPinned: Bool
  /// When this tab was last made active. Persisted now to power auto-archive (Prompt 11); no UI yet.
  public var lastAccessed: Date

  /// The underlying web view. Exposed so a representable can host it directly.
  /// `@ObservationIgnored` because the view itself is not observable state.
  @ObservationIgnored
  public let webView: WKWebView

  /// Called on each *committed* navigation (load finished) with the page URL and title. The app wires
  /// this to record browsing history; `@ObservationIgnored` because it's a sink, not observable state.
  /// Set by `TabManager` so every tab (new, restored, or reseeded) reports through one path.
  @ObservationIgnored
  public var onCommit: ((URL, String) -> Void)?

  /// Called when a navigation turns into a file download (a response the engine can't render, or a
  /// link with the `download` attribute). The app wires this to a `DownloadStore`, which takes over the
  /// `WKDownload`. Set by `TabManager` alongside `onCommit` so every tab reports through one path;
  /// `@ObservationIgnored` because it's a sink, not observable state.
  @ObservationIgnored
  public var onDownloadStart: ((WKDownload) -> Void)?

  @ObservationIgnored
  private var navigationProxy: NavigationProxy!
  @ObservationIgnored
  private var observations: [NSKeyValueObservation] = []

  /// A saved URL waiting to be loaded on first activation (lazy restore). `nil` once loaded or for a
  /// tab that loads eagerly.
  @ObservationIgnored
  private var pendingURL: URL?

  /// Whether this tab still has a deferred restore URL it hasn't loaded yet. `TabManager.rebuildWebViews`
  /// reads this so re-hosting a space's tabs onto a new data store preserves lazy restore instead of
  /// force-loading every tab.
  public var isDeferred: Bool { pendingURL != nil }

  /// Creates a tab.
  ///
  /// Normal use needs no arguments (`WebTab()`), seeding a blank tab the app then loads into. The
  /// remaining parameters exist for **session restore**: pass the persisted `id`, `url`, `title`,
  /// `isPinned`, and `lastAccessed` to recreate a tab as it was. With `deferLoad: true` the saved
  /// `url`/`title` are shown immediately but the page is not fetched until ``ensureLoaded()`` — the
  /// app calls that when the tab first becomes active, so inactive tabs don't all load at launch.
  public init(
    id: UUID = UUID(),
    url: URL? = nil,
    title: String = "",
    isPinned: Bool = false,
    lastAccessed: Date = Date(),
    deferLoad: Bool = false,
    configuration: WKWebViewConfiguration? = nil
  ) {
    self.id = id
    self.isPinned = isPinned
    self.lastAccessed = lastAccessed

    let configuration = configuration ?? WKWebViewConfiguration()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    self.webView = WKWebView(frame: .zero, configuration: configuration)
    // Force a desktop Safari UA so sites (notably Google) serve the full desktop layout instead of
    // treating the default WebKit UA as a lesser/mobile client.
    self.webView.customUserAgent = UserAgent.desktopSafari

    self.navigationProxy = NavigationProxy(owner: self)
    self.webView.navigationDelegate = navigationProxy

    // Seed initial values from the (empty) web view, then keep them in sync via type-safe KVO closures.
    self.url = webView.url
    self.title = webView.title ?? ""
    self.estimatedProgress = webView.estimatedProgress
    self.canGoBack = webView.canGoBack
    self.canGoForward = webView.canGoForward
    registerObservers()

    // Restore path: show the saved url/title right away. Assigning *after* `registerObservers()`
    // overrides the `.initial` KVO callbacks that fired (with the empty web view's nil/"" values)
    // during registration, so the placeholder survives until a real navigation updates it.
    if let url {
      self.url = url
      self.title = title
      if deferLoad {
        self.pendingURL = url
      } else {
        load(url)
      }
    }
  }

  deinit {
    // NSKeyValueObservation invalidates on dealloc, but invalidate explicitly so teardown
    // is deterministic and cannot fire into a deallocating object.
    observations.forEach { $0.invalidate() }
    observations.removeAll()
  }

  private func registerObservers() {
    observations = [
      webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
        MainActor.assumeIsolated { self?.estimatedProgress = webView.estimatedProgress }
      },
      webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
        MainActor.assumeIsolated { self?.title = webView.title ?? "" }
      },
      webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
        MainActor.assumeIsolated { self?.url = webView.url }
      },
      webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
        MainActor.assumeIsolated { self?.canGoBack = webView.canGoBack }
      },
      webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
        MainActor.assumeIsolated { self?.canGoForward = webView.canGoForward }
      },
    ]
  }

  // MARK: - Navigation

  public func load(_ url: URL) {
    webView.load(URLRequest(url: url))
  }

  /// Loads the lazily-deferred restore URL once, if any. Safe to call repeatedly: it does nothing
  /// after the first load (or for a tab that wasn't restored with `deferLoad`).
  public func ensureLoaded() {
    guard let pendingURL else { return }
    self.pendingURL = nil
    load(pendingURL)
  }

  /// Stamps this tab as just used. Call when the tab becomes active so `lastAccessed` reflects real
  /// usage (powers auto-archive in Prompt 11).
  public func markAccessed() {
    lastAccessed = Date()
  }

  public func goBack() {
    webView.goBack()
  }

  public func goForward() {
    webView.goForward()
  }

  public func reload() {
    webView.reload()
  }

  public func stop() {
    webView.stopLoading()
  }

  // MARK: - Favicon

  /// Resolves the best favicon for the current page and publishes it to ``faviconURL``. Asks the page
  /// for its declared `<link rel="icon">` (preferring the highest-resolution / last-declared one), then
  /// resolves it against the page URL. Falls back to the origin's `/favicon.ico` when the page declares
  /// none. Called after each committed navigation.
  func updateFavicon() {
    guard let pageURL = webView.url, let host = pageURL.host(), !host.isEmpty else {
      faviconURL = nil
      return
    }

    // Default fallback: the origin's conventional /favicon.ico.
    var fallback = URLComponents()
    fallback.scheme = pageURL.scheme ?? "https"
    fallback.host = host
    if let port = pageURL.port { fallback.port = port }
    fallback.path = "/favicon.ico"
    let fallbackURL = fallback.url

    let js = """
    (function () {
      var links = Array.from(document.querySelectorAll('link[rel~="icon"], link[rel="shortcut icon"], link[rel="apple-touch-icon"], link[rel="apple-touch-icon-precomposed"]'));
      if (!links.length) return '';
      function size(l) {
        var s = (l.getAttribute('sizes') || '').split('x')[0];
        var n = parseInt(s, 10);
        return isNaN(n) ? 0 : n;
      }
      links.sort(function (a, b) { return size(a) - size(b); });
      var best = links[links.length - 1];
      return best.href || '';
    })()
    """

    webView.evaluateJavaScript(js) { [weak self] result, _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        if let href = result as? String, !href.isEmpty,
           let resolved = URL(string: href, relativeTo: pageURL) {
          self.faviconURL = resolved.absoluteURL
        } else {
          self.faviconURL = fallbackURL
        }
      }
    }
  }

  // MARK: - Navigation delegate proxy

  /// Private delegate that forwards load lifecycle into the owning tab's observable state.
  private final class NavigationProxy: NSObject, WKNavigationDelegate {
    weak var owner: WebTab?

    init(owner: WebTab) {
      self.owner = owner
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      MainActor.assumeIsolated { owner?.isLoading = true }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      MainActor.assumeIsolated {
        guard let owner else { return }
        owner.isLoading = false
        // Navigating counts as using the tab, so refresh recency to keep it out of the archive pass.
        owner.markAccessed()
        // Resolve the page's favicon for the tab strip / address bar.
        owner.updateFavicon()
        // Committed navigation: report the settled URL/title for history recording.
        if let url = webView.url { owner.onCommit?(url, owner.title) }
      }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      MainActor.assumeIsolated { owner?.isLoading = false }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      MainActor.assumeIsolated { owner?.isLoading = false }
    }

    // MARK: Downloads

    /// A link the page asked to download (e.g. an `<a download>`): route it to the download path
    /// instead of navigating. Everything else proceeds as a normal navigation.
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }

    /// A response the engine can't render (e.g. a binary attachment) becomes a download; everything
    /// renderable is allowed through.
    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
      decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    /// WebKit hands us the `WKDownload` for a download that began from a navigation action; forward it
    /// to the owning tab's sink so the app's `DownloadStore` can take it over.
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
      MainActor.assumeIsolated { owner?.onDownloadStart?(download) }
    }

    /// As above, for a download that began from an un-renderable navigation response.
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
      MainActor.assumeIsolated { owner?.onDownloadStart?(download) }
    }
  }
}
