import Foundation
import XCTest
@testable import BrowserCore

final class URLBarParserTests: XCTestCase {
  private let parser = URLBarParser()

  private func url(_ string: String) -> URL { URL(string: string)! }

  // MARK: - URLs

  func testBareDomainGetsHTTPS() {
    XCTAssertEqual(parser.classify("example.com"), .url(url("https://example.com")))
  }

  func testFullURLPreserved() {
    XCTAssertEqual(parser.classify("https://example.com/path?q=1"),
                   .url(url("https://example.com/path?q=1")))
  }

  func testHTTPSchemeNotUpgraded() {
    XCTAssertEqual(parser.classify("http://example.com"), .url(url("http://example.com")))
  }

  func testMissingSchemeOnMultiLabelHost() {
    XCTAssertEqual(parser.classify("news.ycombinator.com"),
                   .url(url("https://news.ycombinator.com")))
  }

  func testDomainWithPathGetsHTTPS() {
    XCTAssertEqual(parser.classify("github.com/apple/swift"),
                   .url(url("https://github.com/apple/swift")))
  }

  // MARK: - localhost / IPs

  func testLocalhostWithPort() {
    XCTAssertEqual(parser.classify("localhost:3000"), .url(url("https://localhost:3000")))
  }

  func testBareLocalhost() {
    XCTAssertEqual(parser.classify("localhost"), .url(url("https://localhost")))
  }

  func testIPv4() {
    XCTAssertEqual(parser.classify("127.0.0.1"), .url(url("https://127.0.0.1")))
  }

  func testIPv4WithPort() {
    XCTAssertEqual(parser.classify("192.168.1.1:8080"), .url(url("https://192.168.1.1:8080")))
  }

  // MARK: - Non-http schemes

  func testAboutScheme() {
    XCTAssertEqual(parser.classify("about:blank"), .url(url("about:blank")))
  }

  func testFileScheme() {
    XCTAssertEqual(parser.classify("file:///tmp/x.html"), .url(url("file:///tmp/x.html")))
  }

  // MARK: - Searches

  func testMultiWordPhraseSearches() {
    XCTAssertEqual(parser.classify("hello world"),
                   .search(url("https://www.google.com/search?q=hello%20world")))
  }

  func testSingleWordNoDotSearches() {
    XCTAssertEqual(parser.classify("swift"),
                   .search(url("https://www.google.com/search?q=swift")))
  }

  func testNumericNonIPSearches() {
    XCTAssertEqual(parser.classify("3.14"),
                   .search(url("https://www.google.com/search?q=3.14")))
  }

  func testReservedQueryCharactersAreEncoded() {
    XCTAssertEqual(parser.classify("a & b = c"),
                   .search(url("https://www.google.com/search?q=a%20%26%20b%20%3D%20c")))
  }

  // MARK: - resolve() + configuration

  func testResolveUnwrapsBothCases() {
    XCTAssertEqual(parser.resolve("example.com"), url("https://example.com"))
    XCTAssertEqual(parser.resolve("hello world"),
                   url("https://www.google.com/search?q=hello%20world"))
  }

  func testCustomSearchTemplate() {
    let ddg = URLBarParser(searchTemplate: "https://duckduckgo.com/?q=")
    XCTAssertEqual(ddg.classify("hello world"),
                   .search(url("https://duckduckgo.com/?q=hello%20world")))
  }

  func testTrimsSurroundingWhitespace() {
    XCTAssertEqual(parser.classify("  example.com  "), .url(url("https://example.com")))
  }
}
