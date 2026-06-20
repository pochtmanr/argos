import SwiftUI
import BrowserCore

struct ContentView: View {
  /// Owned by `MacBrowserApp` and injected, so the app-level menu commands (⌘T/⌘W/cycle) and this
  /// view operate on one shared instance.
  @Environment(TabManager.self) private var manager

  var body: some View {
    VStack(spacing: 0) {
      // TEMPORARY horizontal tab strip — throwaway, replaced by the vertical sidebar in Prompt 04.
      // Exists only to prove multi-tab switching/creation/closing.
      temporaryTabStrip

      if let tab = manager.activeTab {
        ToolbarView(tab: tab)
      }

      content
    }
    .frame(minWidth: 800, minHeight: 600)
    .onAppear {
      // Seed the initial blank tab with the home page (the manager itself is URL-agnostic).
      if manager.activeTab?.url == nil {
        manager.activeTab?.load(homeURL)
      }
    }
  }

  /// Every tab stays mounted in a `ZStack`; only the active one is visible and interactive. Keeping
  /// all `WKWebView` instances alive (rather than swapping a single `WebView`) means switching tabs
  /// never re-hosts or reloads a page — page, scroll, and back/forward state are preserved.
  private var content: some View {
    ZStack {
      ForEach(manager.tabs) { tab in
        WebView(tab: tab)
          .opacity(tab.id == manager.activeTabID ? 1 : 0)
          .allowsHitTesting(tab.id == manager.activeTabID)
      }
    }
  }

  private var temporaryTabStrip: some View {
    HStack(spacing: 4) {
      ForEach(manager.tabs) { tab in
        HStack(spacing: 6) {
          Text(tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title)
            .lineLimit(1)
            .truncationMode(.tail)
          Button {
            manager.closeTab(tab.id)
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.borderless)
          .help("Close Tab")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: 160)
        .background(tab.id == manager.activeTabID ? Color.accentColor.opacity(0.25) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { manager.select(tab.id) }
      }

      Button {
        manager.newTab(url: homeURL)
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(.borderless)
      .help("New Tab")

      Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.bar)
  }
}

#Preview {
  ContentView()
    .environment(TabManager())
}
