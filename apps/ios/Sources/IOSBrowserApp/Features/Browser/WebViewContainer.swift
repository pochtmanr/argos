// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Browser/WebViewContainer.swift
import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
  let profile: BrowserProfile
  @Binding var url: URL
  @Binding var title: String
  @Binding var isLoading: Bool
  @Binding var estimatedProgress: Double

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = ProfileWebsiteDataStore.dataStore(for: profile)
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: [.new], context: nil)
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    if webView.url != url {
      webView.load(URLRequest(url: url))
    }
  }

  static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
    webView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var parent: WebViewContainer

    init(parent: WebViewContainer) {
      self.parent = parent
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
      guard keyPath == "estimatedProgress", let webView = object as? WKWebView else { return }
      parent.estimatedProgress = webView.estimatedProgress
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      parent.isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.isLoading = false
      parent.title = webView.title ?? webView.url?.host() ?? "Untitled"
      if let url = webView.url {
        parent.url = url
      }
    }
  }
}
