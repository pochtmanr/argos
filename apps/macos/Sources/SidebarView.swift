import SwiftUI
import BrowserCore

/// The left sidebar: a vertical `List` of the active space's tabs (native selection highlighting,
/// drag-to-reorder, "new tab" button), with the Spaces switcher pinned at the very bottom.
///
/// The tab list reads `@Environment(TabManager.self)` — `BrowserWindowView` injects the *active
/// space's* manager, so this view stays space-unaware. The switcher reads `SpaceStore` itself.
struct SidebarView: View {
  @Environment(TabManager.self) private var manager
  /// Supplies the configurable home page for the "New Tab" button.
  @Environment(AppSettings.self) private var appSettings

  /// Drives the Archived sheet, opened from the bottom-bar button below the tab list.
  @State private var showingArchived = false

  var body: some View {
    VStack(spacing: 0) {
      // Favorites strip sits above the tab list (shows only when the active Space has favorites).
      FavoritesStripView()

      List(selection: selection) {
        // Pinned tabs render in a sticky section above the rest; only shown when some tab is pinned.
        if !manager.pinnedTabs.isEmpty {
          Section("Pinned") {
            ForEach(manager.pinnedTabs) { tab in
              TabRow(tab: tab)
            }
            .onMove(perform: movePinned)
          }
        }

        Section {
          ForEach(manager.unpinnedTabs) { tab in
            TabRow(tab: tab)
          }
          .onMove(perform: moveUnpinned)
        }
      }
      // Keep the "new tab" button (and the Archived entry, when non-empty) pinned below the list.
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 0) {
          if !manager.archivedTabs.isEmpty {
            archivedButton
          }
          newTabButton
        }
      }

      Divider()

      SpacesSwitcherView()
    }
    // The Archived sheet inherits the active space's `TabManager` from here.
    .sheet(isPresented: $showingArchived) {
      ArchivedView()
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

  /// Opens the Archived sheet, with a count badge so the sidebar shows how many tabs are tucked away.
  private var archivedButton: some View {
    Button {
      showingArchived = true
    } label: {
      HStack {
        Label("Archived", systemImage: "archivebox")
        Spacer(minLength: 4)
        // Count badge: a small pill so the sidebar shows how many tabs are tucked away.
        Text("\(manager.archivedTabs.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(.quaternary, in: Capsule())
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .help("Archived Tabs")
  }

  private var newTabButton: some View {
    Button {
      manager.newTab(url: appSettings.homeURL)
    } label: {
      Label("New Tab", systemImage: "plus")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .help("New Tab")
  }

  /// `.onMove` reports the destination with SwiftUI's insert-before semantics, but the manager's move
  /// removes then inserts (the target is the final index in the shortened array), so adjust when moving
  /// downward. The indices are relative to the section (pinned vs unpinned); the manager maps them back
  /// to the backing tab array. Active selection follows the tab automatically (preserved by identity).
  private func movePinned(from source: IndexSet, to destination: Int) {
    guard let from = source.first else { return }
    manager.movePinned(from: from, to: destination > from ? destination - 1 : destination)
  }

  private func moveUnpinned(from source: IndexSet, to destination: Int) {
    guard let from = source.first else { return }
    manager.moveUnpinned(from: from, to: destination > from ? destination - 1 : destination)
  }
}

#Preview {
  let store = SpaceStore()
  store.activeSpace?.tabManager.newTab(url: URL(string: "https://www.swift.org")!)
  return SidebarView()
    .environment(store)
    .environment(store.activeSpace?.tabManager)
    .environment(try! FavoritesStore(inMemory: true))
    .environment(AppSettings())
}
