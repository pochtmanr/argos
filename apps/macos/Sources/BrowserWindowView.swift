import SwiftUI
import BrowserCore

/// The browser window's root chrome: a `NavigationSplitView` with the vertical tab `SidebarView` on
/// the left and, on the right, the address `ToolbarView` above the active tab's web view.
struct BrowserWindowView: View {
  /// Owned by `MacBrowserApp` and injected, so the app-level menu commands (⌘T/⌘W/cycle) and this
  /// view operate on one shared instance.
  @Environment(TabManager.self) private var manager

  /// Drives the sidebar show/hide toggle and keeps the window usable when collapsed.
  @State private var columnVisibility = NavigationSplitViewVisibility.all

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView()
        .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 360)
    } detail: {
      detailPane
    }
    .frame(minWidth: 900, minHeight: 600)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button {
          withAnimation {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
          }
        } label: {
          Image(systemName: "sidebar.left")
        }
        // ⌥⌘S avoids clashing with the system Toggle-Sidebar item's ⌃⌘S.
        .keyboardShortcut("s", modifiers: [.command, .option])
        .help("Toggle Sidebar")
      }
    }
    .onAppear {
      // Seed the initial blank tab with the home page (the manager itself is URL-agnostic).
      if manager.activeTab?.url == nil {
        manager.activeTab?.load(homeURL)
      }
    }
  }

  /// The detail pane: address toolbar atop the active tab's content. Every tab stays mounted in a
  /// `ZStack`; only the active one is visible and interactive. Keeping all `WKWebView` instances
  /// alive (rather than swapping a single `WebView`) means switching tabs never re-hosts or reloads a
  /// page — page, scroll, and back/forward state are preserved.
  private var detailPane: some View {
    VStack(spacing: 0) {
      if let tab = manager.activeTab {
        ToolbarView(tab: tab)
      }

      ZStack {
        ForEach(manager.tabs) { tab in
          WebView(tab: tab)
            .opacity(tab.id == manager.activeTabID ? 1 : 0)
            .allowsHitTesting(tab.id == manager.activeTabID)
        }
      }
    }
  }
}

#Preview {
  BrowserWindowView()
    .environment(TabManager())
}
