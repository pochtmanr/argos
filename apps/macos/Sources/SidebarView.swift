import SwiftUI
import BrowserCore

/// The left sidebar, now focused on **Spaces/Profiles** (tabs moved to the top `TabStripView`). Top to
/// bottom: the active Space's Favorites strip, the Spaces switcher (the main content), and an Archived
/// entry pinned at the bottom when the Space has archived tabs.
///
/// Reads `@Environment(TabManager.self)` — `BrowserWindowView` injects the active space's manager — for
/// the Favorites strip and the archived-tab count/sheet. The switcher reads `SpaceStore` itself.
struct SidebarView: View {
  @Environment(TabManager.self) private var manager

  /// Drives the Archived sheet, opened from the bottom-bar button.
  @State private var showingArchived = false

  var body: some View {
    VStack(spacing: 0) {
      // Favorites strip sits above the spaces list (shows only when the active Space has favorites).
      FavoritesStripView()

      ScrollView {
        SpacesSwitcherView()
      }
      .frame(maxHeight: .infinity)

      // Keep the Archived entry pinned at the bottom when the active Space has archived tabs.
      if !manager.archivedTabs.isEmpty {
        Divider()
        archivedButton
      }
    }
    // The Archived sheet inherits the active space's `TabManager` from here.
    .sheet(isPresented: $showingArchived) {
      ArchivedView()
    }
  }

  /// Opens the Archived sheet, with a count badge so the sidebar shows how many tabs are tucked away.
  private var archivedButton: some View {
    Button {
      showingArchived = true
    } label: {
      HStack {
        Label("Archived", systemImage: "archivebox")
        Spacer(minLength: 4)
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
}

#Preview {
  let store = SpaceStore()
  store.activeSpace?.tabManager.newTab(url: URL(string: "https://www.swift.org")!)
  return SidebarView()
    .environment(store)
    .environment(store.activeSpace?.tabManager)
    .environment(WindowState())
    .environment(try! FavoritesStore(inMemory: true))
    .environment(AppSettings())
}
