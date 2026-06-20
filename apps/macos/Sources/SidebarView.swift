import SwiftUI
import BrowserCore

/// The left sidebar: a vertical `List` of the active space's tabs (native selection highlighting,
/// drag-to-reorder, "new tab" button), with the Spaces switcher pinned at the very bottom.
///
/// The tab list reads `@Environment(TabManager.self)` — `BrowserWindowView` injects the *active
/// space's* manager, so this view stays space-unaware. The switcher reads `SpaceStore` itself.
struct SidebarView: View {
  @Environment(TabManager.self) private var manager

  var body: some View {
    VStack(spacing: 0) {
      List(selection: selection) {
        ForEach(manager.tabs) { tab in
          TabRow(tab: tab)
        }
        .onMove(perform: move)
      }
      // Keep the "new tab" button pinned below the scrolling list.
      .safeAreaInset(edge: .bottom) {
        newTabButton
      }

      Divider()

      SpacesSwitcherView()
    }
  }

  /// `activeTabID` is `private(set)`, so we can't bind to it directly. Read it for the highlight and
  /// route writes through `select` so a row tap activates the tab.
  private var selection: Binding<WebTab.ID?> {
    Binding(
      get: { manager.activeTabID },
      set: { if let id = $0 { manager.select(id) } }
    )
  }

  private var newTabButton: some View {
    Button {
      manager.newTab(url: homeURL)
    } label: {
      Label("New Tab", systemImage: "plus")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .help("New Tab")
  }

  /// `.onMove` reports the destination with SwiftUI's insert-before semantics, but
  /// `TabManager.move(from:to:)` removes then inserts (the target is the final index in the shortened
  /// array). Adjust when moving downward. Active selection follows the tab automatically because the
  /// manager preserves `activeTabID` by identity.
  private func move(from source: IndexSet, to destination: Int) {
    guard let from = source.first else { return }
    let to = destination > from ? destination - 1 : destination
    manager.move(from: from, to: to)
  }
}

#Preview {
  let store = SpaceStore()
  store.activeSpace?.tabManager.newTab(url: URL(string: "https://www.swift.org")!)
  return SidebarView()
    .environment(store)
    .environment(store.activeSpace?.tabManager)
}
