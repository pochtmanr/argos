import SwiftUI
import WebKit

#if os(macOS)

/// Hosts a `WebTab`'s `WKWebView` in SwiftUI on macOS.
///
/// The web view is owned by the `WebTab`; this representable never recreates it.
public struct WebView: NSViewRepresentable {
  private let tab: WebTab

  public init(tab: WebTab) {
    self.tab = tab
  }

  public func makeNSView(context: Context) -> WKWebView {
    tab.webView
  }

  public func updateNSView(_ nsView: WKWebView, context: Context) {
    // No-op: the tab owns the web view and drives navigation. Reusing the existing
    // instance avoids tearing down/reloading the page on every SwiftUI update.
  }
}

#elseif os(iOS)

/// Hosts a `WebTab`'s `WKWebView` in SwiftUI on iOS.
///
/// The web view is owned by the `WebTab`; this representable never recreates it.
public struct WebView: UIViewRepresentable {
  private let tab: WebTab

  public init(tab: WebTab) {
    self.tab = tab
  }

  public func makeUIView(context: Context) -> WKWebView {
    tab.webView
  }

  public func updateUIView(_ uiView: WKWebView, context: Context) {
    // No-op: the tab owns the web view and drives navigation.
  }
}

#endif
