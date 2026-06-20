// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/App/IOSBrowserApp.swift
import SwiftUI

@main
struct IOSBrowserApp: App {
  @State private var profileStore = ProfileStore()
  @State private var browserState = BrowserState()

  var body: some Scene {
    WindowGroup {
      AppShellView()
        .environment(profileStore)
        .environment(browserState)
    }
  }
}
