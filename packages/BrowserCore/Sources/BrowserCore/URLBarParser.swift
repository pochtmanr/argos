import Foundation

/// Decides whether text typed into the address bar is a URL to visit or a query to search.
///
/// Pure and platform-agnostic (`Foundation` only) so it is unit-testable and reusable by the
/// macOS toolbar, the iOS UI, and the command bar (Prompt 07).
public struct URLBarParser: Sendable {
  /// The outcome of interpreting a piece of input.
  public enum Resolution: Equatable, Sendable {
    /// The input was understood as a location to navigate to directly.
    case url(URL)
    /// The input was understood as a search query; the associated URL hits the search engine.
    case search(URL)
  }

  /// Search-engine template. The query is percent-encoded and appended to this string.
  /// Defaults to Google.
  public var searchTemplate: String

  public init(searchTemplate: String = "https://www.google.com/search?q=") {
    self.searchTemplate = searchTemplate
  }

  /// Interprets `input` and returns the URL to load, whether that is a direct navigation or a
  /// search. Convenience over ``classify(_:)`` for callers that only need the final URL.
  public func resolve(_ input: String) -> URL {
    switch classify(input) {
    case let .url(url), let .search(url):
      return url
    }
  }

  /// The testable core: classifies `input` as a direct URL or a search without loading anything.
  public func classify(_ input: String) -> Resolution {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else { return search(for: trimmed) }

    // 1. Explicit scheme (http(s)://, about:, file:, mailto:, …) → take as-is.
    if hasScheme(trimmed), let url = URL(string: trimmed) {
      return .url(url)
    }

    // 2. localhost / IP literals, and 3. anything that looks like a domain → assume https.
    if isLocalhostOrIP(trimmed) || looksLikeDomain(trimmed),
       let url = URL(string: "https://\(trimmed)") {
      return .url(url)
    }

    // 4. Otherwise treat it as a search query.
    return search(for: trimmed)
  }

  // MARK: - Helpers

  /// Builds a `.search` resolution for `query`, percent-encoding it for use in a query string.
  private func search(for query: String) -> Resolution {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? query
    // Fall back to a bare Google search of the raw input if the template is somehow malformed.
    let url = URL(string: searchTemplate + encoded)
      ?? URL(string: "https://www.google.com/search?q=\(encoded)")!
    return .search(url)
  }

  /// True when the input begins with a URL scheme, e.g. `https:`, `about:`, `file:`, `mailto:`.
  private func hasScheme(_ input: String) -> Bool {
    guard let colon = input.firstIndex(of: ":") else { return false }
    let scheme = input[input.startIndex..<colon]
    guard let first = scheme.first, first.isLetter else { return false }
    guard scheme.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." })
    else { return false }

    // Disambiguate `host:port` (e.g. `localhost:3000`) from a real scheme: if the segment right
    // after the colon is all digits, it's a port — treat the whole thing as a host instead.
    let afterColon = input[input.index(after: colon)...]
    let portCandidate = afterColon.prefix { $0 != "/" }
    if !portCandidate.isEmpty && portCandidate.allSatisfy(\.isNumber) { return false }
    return true
  }

  /// Recognises `localhost` (with optional `:port`/path) and IPv4/bracketed-IPv6 literals.
  private func isLocalhostOrIP(_ input: String) -> Bool {
    // Host is everything before the first `/`, `?`, or `#`.
    let host = input.prefix { $0 != "/" && $0 != "?" && $0 != "#" }

    // localhost, optionally with a :port.
    let hostNoPort = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? String(host)
    if hostNoPort == "localhost" { return true }

    // Bracketed IPv6, e.g. [::1] or [::1]:8080.
    if host.first == "[" { return true }

    // IPv4: four dot-separated 0–255 octets, optionally with a :port.
    let octets = hostNoPort.split(separator: ".", omittingEmptySubsequences: false)
    if octets.count == 4,
       octets.allSatisfy({ part in
         part.count >= 1 && part.allSatisfy(\.isNumber) && (UInt8(part) != nil)
       }) {
      return true
    }
    return false
  }

  /// Heuristic for "this is a hostname, not a search phrase": no spaces, and the host portion has
  /// a dot followed by a plausible TLD (≥2 letters).
  private func looksLikeDomain(_ input: String) -> Bool {
    guard !input.contains(" ") else { return false }

    // Host is everything before the first `/`, `?`, `#`, then strip any `:port`.
    let host = input.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
    let hostNoPort = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? String(host)

    let labels = hostNoPort.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2, let tld = labels.last else { return false }

    // Every label must be non-empty (rejects "foo." / ".com" / "a..b").
    guard labels.allSatisfy({ !$0.isEmpty }) else { return false }

    // TLD must be ≥2 chars and all letters (rejects "1.2", "version2.0", etc.).
    return tld.count >= 2 && tld.allSatisfy(\.isLetter)
  }
}

private extension CharacterSet {
  /// `.urlQueryAllowed` minus the sub-delimiters that have meaning inside a query *value*
  /// (notably `+`, `&`, `=`), so spaces and reserved characters encode correctly.
  static let urlQueryValueAllowed: CharacterSet = {
    var set = CharacterSet.urlQueryAllowed
    set.remove(charactersIn: "+&=?/")
    return set
  }()
}
