import SwiftUI
import BrowserCore

struct ContentView: View {
  /// Single tab for now. Multiple tabs arrive in later prompts.
  @State private var tab = WebTab()

  private let homeURL = URL(string: "https://www.apple.com")!

  var body: some View {
    VStack(spacing: 0) {
      ToolbarView(tab: tab)
      WebView(tab: tab)
    }
    .frame(minWidth: 800, minHeight: 600)
    .onAppear { tab.load(homeURL) }
  }
}

#Preview {
  ContentView()
}
