import SwiftUI
import BrowserCore

struct ContentView: View {
  /// Single tab for now. Multiple tabs + a real address bar arrive in later prompts.
  @State private var tab = WebTab()

  private let homeURL = URL(string: "https://www.apple.com")!

  var body: some View {
    VStack(spacing: 0) {
      // TEMPORARY top strip — throwaway, replaced by a real toolbar in Prompt 02.
      // Exists only to prove the observable wiring (title + progress).
      temporaryStrip

      WebView(tab: tab)
    }
    .frame(minWidth: 800, minHeight: 600)
    .onAppear { tab.load(homeURL) }
  }

  private var temporaryStrip: some View {
    VStack(spacing: 4) {
      HStack(spacing: 8) {
        Button(action: tab.goBack) { Image(systemName: "chevron.left") }
          .disabled(!tab.canGoBack)
        Button(action: tab.goForward) { Image(systemName: "chevron.right") }
          .disabled(!tab.canGoForward)
        Button(action: { tab.isLoading ? tab.stop() : tab.reload() }) {
          Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
        }

        Text(tab.title.isEmpty ? (tab.url?.host() ?? "Loading…") : tab.title)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.borderless)
      .padding(.horizontal, 12)
      .padding(.top, 8)

      ProgressView(value: tab.estimatedProgress)
        .progressViewStyle(.linear)
        .opacity(tab.isLoading ? 1 : 0)
    }
    .padding(.bottom, 4)
    .background(.bar)
    // Reference BrowserCore version to keep the SPM link obvious.
    .help("BrowserCore v\(BrowserCoreInfo.version)")
  }
}

#Preview {
  ContentView()
}
