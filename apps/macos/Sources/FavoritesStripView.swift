import SwiftUI
import BrowserCore

/// A compact, horizontal strip of the active Space's favorites, shown at the top of the sidebar. Each
/// favorite is an icon button: click opens it in a new tab, the context menu removes it, and items
/// drag to reorder. Hidden entirely when the Space has no favorites so the sidebar stays clean.
///
/// Reads this window's `WindowState` for the active Space id (the sidebar is otherwise Space-unaware)
/// and the active `TabManager` to open the chosen favorite. Per-window, so two windows showing
/// different Spaces each show their own Space's favorites.
struct FavoritesStripView: View {
  @Environment(WindowState.self) private var windowState
  @Environment(FavoritesStore.self) private var favorites
  @Environment(TabManager.self) private var manager

  private var items: [Favorite] { favorites.all(spaceID: windowState.activeSpaceID) }

  var body: some View {
    if !items.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(items) { favorite in
            favoriteButton(favorite)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
      }
      Divider()
    }
  }

  private func favoriteButton(_ favorite: Favorite) -> some View {
    Button {
      manager.newTab(url: favorite.url)
    } label: {
      // Placeholder favicon — matches `TabRow`'s globe until real favicons land.
      Image(systemName: "globe")
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.borderless)
    .help(favorite.title.isEmpty ? favorite.url.absoluteString : favorite.title)
    .contextMenu {
      Button("Remove from Favorites", role: .destructive) {
        favorites.remove(favorite)
      }
    }
    .draggable(favorite.url.absoluteString) {
      Image(systemName: "globe").frame(width: 24, height: 24)
    }
    .dropDestination(for: String.self) { dropped, _ in
      reorder(droppedURLString: dropped.first, before: favorite)
    }
  }

  /// Reorders the dropped favorite to sit before `target` within the active Space.
  private func reorder(droppedURLString: String?, before target: Favorite) -> Bool {
    guard let droppedURLString,
          let from = items.firstIndex(where: { $0.url.absoluteString == droppedURLString }),
          let to = items.firstIndex(where: { $0.id == target.id }),
          from != to else { return false }
    // `move(from:to:)` uses remove-then-insert; adjust when dragging downward so the item lands
    // before the target (same convention as the tab list's `.onMove`).
    favorites.move(from: from, to: from < to ? to - 1 : to, in: windowState.activeSpaceID)
    return true
  }
}
