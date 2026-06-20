import Foundation
import Network

/// Parses a user-pasted proxy string into a Network-framework `ProxyConfiguration`, which a
/// `WKWebsiteDataStore` applies via its `proxyConfigurations` (macOS 14+).
///
/// Accepted forms (scheme and credentials optional; default scheme is SOCKS5):
/// - `socks5://user:pass@host:1080`
/// - `http://host:8080`
/// - `host:1080`
public enum ProxyConfigParser {
  /// Builds a `ProxyConfiguration` from `raw`, or `nil` when the string is empty or cannot be parsed
  /// into a host + port.
  public static func configuration(from raw: String) -> ProxyConfiguration? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    // Optional `scheme://` prefix.
    var scheme = "socks5"
    var rest = trimmed
    if let schemeRange = trimmed.range(of: "://") {
      scheme = String(trimmed[..<schemeRange.lowerBound]).lowercased()
      rest = String(trimmed[schemeRange.upperBound...])
    }

    // Optional `user:pass@` (or `user@`) credentials.
    var username: String?
    var password: String?
    if let at = rest.lastIndex(of: "@") {
      let credentials = String(rest[..<at])
      rest = String(rest[rest.index(after: at)...])
      if let colon = credentials.firstIndex(of: ":") {
        username = String(credentials[..<colon])
        password = String(credentials[credentials.index(after: colon)...])
      } else {
        username = credentials
      }
    }

    // Required `host:port`.
    guard let colon = rest.lastIndex(of: ":") else { return nil }
    let host = String(rest[..<colon])
    let portString = String(rest[rest.index(after: colon)...])
    guard !host.isEmpty, let port = NWEndpoint.Port(portString) else { return nil }

    let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)
    let configuration: ProxyConfiguration
    switch scheme {
    case "http", "https":
      configuration = ProxyConfiguration(httpCONNECTProxy: endpoint)
    default:
      configuration = ProxyConfiguration(socksv5Proxy: endpoint)
    }

    if let username {
      configuration.applyCredential(username: username, password: password ?? "")
    }
    return configuration
  }
}
