// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Browser/BrowserState.swift
import Foundation
import Observation

@MainActor
@Observable
final class BrowserState {
  var currentURL = URL(string: "https://example.com")!
  var pageTitle = "Example Domain"
  var isLoading = false
  var estimatedProgress = 0.0

  func navigate(to url: URL) {
    currentURL = url
  }
}
