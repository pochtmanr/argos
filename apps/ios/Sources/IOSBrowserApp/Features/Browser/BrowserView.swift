// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Browser/BrowserView.swift
import SwiftUI

struct BrowserView: View {
  @Environment(ProfileStore.self) private var profileStore
  @Environment(BrowserState.self) private var browserState
  @State private var addressText = "https://example.com"

  var body: some View {
    @Bindable var state = browserState
    VStack(spacing: 0) {
      HStack {
        TextField("Address", text: $addressText)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
          .autocorrectionDisabled()
          .textFieldStyle(.roundedBorder)
          .onSubmit(navigate)
        Button(action: navigate) {
          Label("Go", systemImage: "arrow.right")
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(12)

      if state.isLoading {
        ProgressView(value: state.estimatedProgress)
      }

      WebViewContainer(
        profile: profileStore.activeProfile,
        url: $state.currentURL,
        title: $state.pageTitle,
        isLoading: $state.isLoading,
        estimatedProgress: $state.estimatedProgress
      )
    }
  }

  private func navigate() {
    guard let url = URL(string: addressText) else { return }
    browserState.navigate(to: url)
  }
}
