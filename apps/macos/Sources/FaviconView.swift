import SwiftUI

/// Fetches and displays a site's favicon for a saved URL — used by the favorites strip and the
/// new-tab start page, neither of which has a live `WebTab`/`faviconURL` to read from.
///
/// The icon is resolved from the site's **own** `/favicon.ico` (first-party only): an anti-detect /
/// privacy browser must never route favicon lookups through a third-party favicon service, which would
/// leak the user's saved domains. While the image loads — or when a site has no reachable icon — it
/// falls back to the same tinted globe the tab strip uses, so a missing favicon degrades gracefully.
struct FaviconView: View {
  /// The saved page URL whose site icon to show.
  let pageURL: URL
  /// Rendered icon edge length in points.
  var size: CGFloat = 16

  /// The conventional first-party favicon location for `pageURL`'s origin, or `nil` if the URL has no
  /// host (so we just show the globe).
  private var iconURL: URL? {
    guard let host = pageURL.host(), !host.isEmpty else { return nil }
    var components = URLComponents()
    components.scheme = pageURL.scheme == "http" ? "http" : "https"
    components.host = host
    if let port = pageURL.port { components.port = port }
    components.path = "/favicon.ico"
    return components.url
  }

  var body: some View {
    Group {
      if let iconURL {
        AsyncImage(url: iconURL) { image in
          image.resizable().interpolation(.medium)
        } placeholder: {
          globe
        }
      } else {
        globe
      }
    }
    .frame(width: size, height: size)
  }

  private var globe: some View {
    Image(systemName: "globe")
      .resizable()
      .scaledToFit()
      .padding(size * 0.08)
      .foregroundStyle(.secondary)
  }
}
