import SwiftUI
import BrowserCore

/// One row in the vertical tab sidebar: favicon placeholder, title (falling back to host/URL), and a
/// close button that appears on hover. Selection highlighting is handled natively by the enclosing
/// `List`, so this view only renders content and exposes the close affordance.
struct TabRow: View {
  let tab: WebTab

  @Environment(TabManager.self) private var manager
  @Environment(WindowState.self) private var windowState
  @Environment(FavoritesStore.self) private var favorites
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 8) {
      // Favicon affordance — placeholder for now; real favicons arrive later.
      Image(systemName: "globe")
        .foregroundStyle(.secondary)

      Text(tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title)
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer(minLength: 4)

      // Close affordance stays hidden until hover to keep the row uncluttered. ⌘W closes the active
      // tab via the app menu; this targets any row directly.
      if hovering {
        Button {
          manager.closeTab(tab.id)
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Close Tab")
      }
    }
    // Make the whole row hit-testable so taps anywhere select it (List handles the selection).
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .contextMenu { contextMenu }
  }

  @ViewBuilder
  private var contextMenu: some View {
    Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
      manager.togglePin(tab.id)
    }

    let isFavorite = tab.url.map { favorites.contains(url: $0, in: windowState.activeSpaceID) } ?? false
    Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
      guard let url = tab.url else { return }
      favorites.toggle(url: url, title: tab.title, spaceID: windowState.activeSpaceID)
    }
    .disabled(tab.url == nil)

    Divider()

    Button("Close Tab", role: .destructive) {
      manager.closeTab(tab.id)
    }
  }
}

#Preview {
  let store = SpaceStore()
  let manager = store.activeSpace!.tabManager
  manager.activeTab?.load(URL(string: "https://www.apple.com")!)
  return List {
    TabRow(tab: manager.activeTab!)
  }
  .environment(manager)
  .environment(WindowState())
  .environment(try! FavoritesStore(inMemory: true))
}
