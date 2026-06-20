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
public final class WebTab {
  /// The current page URL, kept in sync via KVO.
  public private(set) var url: URL?
  /// The current page title, kept in sync via KVO.
  public private(set) var title: String = ""
  /// Load progress in `0...1`, kept in sync via KVO.
  public private(set) var estimatedProgress: Double = 0
  /// Whether a navigation is in flight (driven by the navigation delegate).
  public private(set) var isLoading: Bool = false
  /// Whether the back list is non-empty.
  public private(set) var canGoBack: Bool = false
  /// Whether the forward list is non-empty.
  public private(set) var canGoForward: Bool = false

  /// The underlying web view. Exposed so a representable can host it directly.
  /// `@ObservationIgnored` because the view itself is not observable state.
  @ObservationIgnored
  public let webView: WKWebView

  @ObservationIgnored
  private var navigationProxy: NavigationProxy!
  @ObservationIgnored
  private var observations: [NSKeyValueObservation] = []

  public init(configuration: WKWebViewConfiguration? = nil) {
    let configuration = configuration ?? WKWebViewConfiguration()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    self.webView = WKWebView(frame: .zero, configuration: configuration)

    self.navigationProxy = NavigationProxy(owner: self)
    self.webView.navigationDelegate = navigationProxy

    // Seed initial values, then keep them in sync via type-safe KVO closures.
    self.url = webView.url
    self.title = webView.title ?? ""
    self.estimatedProgress = webView.estimatedProgress
    self.canGoBack = webView.canGoBack
    self.canGoForward = webView.canGoForward
    registerObservers()
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
      MainActor.assumeIsolated { owner?.isLoading = false }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      MainActor.assumeIsolated { owner?.isLoading = false }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      MainActor.assumeIsolated { owner?.isLoading = false }
    }
  }
}
