import AppKit
import BrowserCore
import SwiftUI

/// The new-tab start page (shown by `BrowserWindowView`'s detail pane whenever the active tab has no
/// URL). Presents the active Space's favorites and the All-Spaces favorites in two grids; clicking a
/// tile navigates *this* tab to that site, dragging reorders within a section, and the context menu
/// removes a favorite. Mirrors the drag/drop reorder convention used by `FavoritesStripView`.
///
/// Reads this window's `WindowState` for the active Space id and the shared `FavoritesStore`.
struct StartPageView: View {
  /// The active (blank) tab to navigate when a favorite is clicked.
  let tab: WebTab

  @Environment(WindowState.self) private var windowState
  @Environment(FavoritesStore.self) private var favorites

  private var spaceItems: [Favorite] { favorites.all(spaceID: windowState.activeSpaceID) }
  private var globalItems: [Favorite] { favorites.all(spaceID: nil) }

  private let columns = [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 16)]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        if spaceItems.isEmpty && globalItems.isEmpty {
          emptyState
        } else {
          if !spaceItems.isEmpty {
            section(title: "This Space", items: spaceItems, spaceID: windowState.activeSpaceID)
          }
          if !globalItems.isEmpty {
            section(title: "All Spaces", items: globalItems, spaceID: nil)
          }
        }
      }
      .frame(maxWidth: 720, alignment: .leading)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 40)
      .padding(.vertical, 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .textBackgroundColor))
  }

  @ViewBuilder
  private func section(title: String, items: [Favorite], spaceID: UUID?) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.secondary)
      LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
        ForEach(items) { favorite in
          tile(favorite, in: spaceID, items: items)
        }
      }
    }
  }

  private func tile(_ favorite: Favorite, in spaceID: UUID?, items: [Favorite]) -> some View {
    Button {
      tab.load(favorite.url)
    } label: {
      VStack(spacing: 8) {
        // The site's own favicon (falls back to a globe while loading / when the site has none).
        FaviconView(pageURL: favorite.url, size: 32)
          .frame(width: 64, height: 64)
          .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.12)))
        Text(label(for: favorite))
          .font(.caption)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: 88)
      }
    }
    .buttonStyle(.plain)
    .help(favorite.title.isEmpty ? favorite.url.absoluteString : favorite.title)
    .contextMenu {
      Button("Remove from Favorites", role: .destructive) {
        favorites.remove(favorite)
      }
    }
    .draggable(favorite.url.absoluteString) {
      FaviconView(pageURL: favorite.url, size: 32).frame(width: 64, height: 64)
    }
    .dropDestination(for: String.self) { dropped, _ in
      reorder(droppedURLString: dropped.first, before: favorite, in: spaceID, items: items)
    }
  }

  private func label(for favorite: Favorite) -> String {
    if !favorite.title.isEmpty { return favorite.title }
    return favorite.url.host() ?? favorite.url.absoluteString
  }

  /// Reorders the dropped favorite to sit before `target` within `items` (one section/scope). Drops
  /// whose URL isn't in this section are ignored, so favorites don't jump between scopes. Same
  /// remove-then-insert adjustment as `FavoritesStripView.reorder`.
  private func reorder(droppedURLString: String?, before target: Favorite, in spaceID: UUID?, items: [Favorite]) -> Bool {
    guard let droppedURLString,
          let from = items.firstIndex(where: { $0.url.absoluteString == droppedURLString }),
          let to = items.firstIndex(where: { $0.id == target.id }),
          from != to else { return false }
    favorites.move(from: from, to: from < to ? to - 1 : to, in: spaceID)
    return true
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "star")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)
      Text("No Favorites Yet")
        .font(.title3.weight(.semibold))
      Text("Star a page to add it here.")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 320)
  }
}
