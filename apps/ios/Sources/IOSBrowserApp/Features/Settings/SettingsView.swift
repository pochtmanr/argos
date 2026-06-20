// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Section("Privacy") {
        Label("Profile data uses WKWebView storage boundaries available on iOS.", systemImage: "lock.shield")
      }
      Section("Sync") {
        Label("Encrypted sync is configured through the backend mutation log.", systemImage: "arrow.triangle.2.circlepath")
      }
    }
    .navigationTitle("Settings")
  }
}
