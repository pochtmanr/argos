import SwiftUI
import BrowserCore

/// The browser window's root chrome: a `NavigationSplitView` with the vertical tab `SidebarView`
/// (plus the Spaces switcher) on the left and, on the right, the address `ToolbarView` above the
/// active tab's web view.
///
/// `SpaceStore` is the single source of truth. The active space's `TabManager` is injected into the
/// environment so the tab `SidebarView`/`TabRow`/detail pane keep operating on a plain `TabManager`,
/// unaware of spaces — switching spaces just swaps which manager they see.
struct BrowserWindowView: View {
  @Environment(SpaceStore.self) private var store

  /// Drives the sidebar show/hide toggle and keeps the window usable when collapsed.
  @State private var columnVisibility = NavigationSplitViewVisibility.all

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView()
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
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
    // Scope the tab views to the active space's manager. Always non-nil given the never-empty
    // invariant; re-injected when the active space changes so the sidebar/detail swap tab sets.
    .environment(store.activeSpace?.tabManager)
    // Load a lazily-restored tab the first time it becomes active — on launch and on every space/tab
    // switch — and stamp it accessed (powers auto-archive, Prompt 11). `.task(id:)` re-runs whenever
    // the active (space, tab) pair changes.
    .task(id: activeTabKey) {
      guard let tab = store.activeSpace?.tabManager.activeTab else { return }
      tab.markAccessed()
      tab.ensureLoaded()
    }
  }

  /// Identity of the active (space, tab) pair, so `.task(id:)` fires once per distinct activation.
  private var activeTabKey: String {
    let space = store.activeSpaceID?.uuidString ?? "none"
    let tab = store.activeSpace?.tabManager.activeTabID?.uuidString ?? "none"
    return "\(space):\(tab)"
  }

  /// The detail pane: address toolbar atop the active space's active tab content. Every tab in the
  /// active space stays mounted in a `ZStack`; only the active one is visible and interactive.
  /// Keeping the `WKWebView`s alive (rather than swapping a single `WebView`) means switching tabs
  /// never re-hosts or reloads a page. Only the active space's tabs are mounted; inactive spaces'
  /// web views stay alive in memory but leave the hierarchy until that space is reselected, so
  /// switching back is instant with page/scroll/history intact (no suspension this prompt).
  @ViewBuilder
  private var detailPane: some View {
    if let space = store.activeSpace, let tab = space.tabManager.activeTab {
      VStack(spacing: 0) {
        // `.id(tab.id)` gives the toolbar fresh @State (address text/focus) when the active tab
        // identity changes — including across a space switch.
        ToolbarView(tab: tab)
          .id(tab.id)

        ZStack {
          ForEach(space.tabManager.tabs) { tab in
            WebView(tab: tab)
              .opacity(tab.id == space.tabManager.activeTabID ? 1 : 0)
              .allowsHitTesting(tab.id == space.tabManager.activeTabID)
          }
        }
        // Make the per-space web-view container identity explicit across space switches.
        .id(space.id)
      }
    }
  }
}

#Preview {
  BrowserWindowView()
    .environment(SpaceStore())
}
