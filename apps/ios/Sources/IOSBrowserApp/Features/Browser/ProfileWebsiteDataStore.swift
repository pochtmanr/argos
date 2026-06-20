// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Browser/ProfileWebsiteDataStore.swift
import WebKit

enum ProfileWebsiteDataStore {
  static func dataStore(for profile: BrowserProfile) -> WKWebsiteDataStore {
    // WKWebView is mandatory on iOS. Use non-persistent stores for profile isolation by default;
    // persistent multi-profile Chromium-style storage is not available on iOS.
    _ = profile
    return .nonPersistent()
  }
}
