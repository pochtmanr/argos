import Foundation

/// Browser user-agent strings.
///
/// A fresh `WKWebView` on macOS reports a WebKit UA that some sites (notably Google) treat as a
/// lesser/mobile client, serving a degraded layout. Forcing a current desktop Safari UA on every tab
/// makes those sites serve their full desktop experience. Set in ``WebTab/init`` via
/// `webView.customUserAgent`.
public enum UserAgent {
  /// A current desktop macOS Safari user-agent. Bump the `Version/…` segment as Safari advances.
  public static let desktopSafari =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"
}
