import SwiftUI
import BrowserCore

/// The active Space's bookmarks, shown as a compact 2-column grid of tile cards at the top of the
/// sidebar — each tile is the site's favicon over its name. Click opens it in a new tab, the context
/// menu removes it, and tiles drag to reorder. Capped at 8 so the section stays glanceable, and
/// hidden entirely when the Space has no favorites so the sidebar stays clean.
///
/// Reads this window's `WindowState` for the active Space id (the sidebar is otherwise Space-unaware)
/// and the active `TabManager` to open the chosen favorite. Per-window, so two windows showing
/// different Spaces each show their own Space's favorites.
struct FavoritesStripView: View {
  @Environment(WindowState.self) private var windowState
  @Environment(FavoritesStore.self) private var favorites
  @Environment(TabManager.self) private var manager

  /// The first 8 favorites of the active Space (the grid is meant to glance, not scroll).
  private var items: [Favorite] { Array(favorites.all(spaceID: windowState.activeSpaceID).prefix(8)) }

  private let columns = [
    GridItem(.flexible(), spacing: 8),
    GridItem(.flexible(), spacing: 8),
  ]

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Bookmarks")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 2)

        LazyVGrid(columns: columns, spacing: 8) {
          ForEach(items) { favorite in
            tile(favorite)
          }
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      Divider()
    }
  }

  private func tile(_ favorite: Favorite) -> some View {
    Button {
      manager.newTab(url: favorite.url)
    } label: {
      VStack(spacing: 6) {
        // The site's own favicon (falls back to a globe while loading / when the site has none).
        FaviconView(pageURL: favorite.url, size: 22)
          .frame(width: 22, height: 22)
        Text(label(for: favorite))
          .font(.caption2)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .padding(.horizontal, 6)
      .background(tileBackground(for: favorite))
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .onHover { hoveringID = $0 ? favorite.id : (hoveringID == favorite.id ? nil : hoveringID) }
    .help(favorite.title.isEmpty ? favorite.url.absoluteString : favorite.title)
    .contextMenu {
      Button("Remove from Favorites", role: .destructive) {
        favorites.remove(favorite)
      }
    }
    .draggable(favorite.url.absoluteString) {
      FaviconView(pageURL: favorite.url, size: 22).frame(width: 22, height: 22)
    }
    .dropDestination(for: String.self) { dropped, _ in
      reorder(droppedURLString: dropped.first, before: favorite)
    }
  }

  /// Tracks which tile the pointer is over so the card can brighten on hover.
  @State private var hoveringID: Favorite.ID?

  private func tileBackground(for favorite: Favorite) -> some View {
    let hovering = hoveringID == favorite.id
    return RoundedRectangle(cornerRadius: 12)
      .fill(Color.secondary.opacity(hovering ? 0.16 : 0.08))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.05)))
  }

  /// The tile caption: the favorite's title, falling back to its host.
  private func label(for favorite: Favorite) -> String {
    if !favorite.title.isEmpty { return favorite.title }
    return favorite.url.host() ?? favorite.url.absoluteString
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

#Preview {
  let store = SpaceStore()
  let spaceID = store.activeSpace?.id
  let favorites = try! FavoritesStore(inMemory: true)
  for (title, urlString) in [
    ("Swift", "https://www.swift.org"),
    ("Apple", "https://www.apple.com"),
    ("GitHub", "https://github.com"),
    ("Hacker News", "https://news.ycombinator.com"),
    ("Wikipedia", "https://www.wikipedia.org"),
    ("Anthropic", "https://www.anthropic.com"),
  ] {
    _ = favorites.add(url: URL(string: urlString)!, title: title, spaceID: spaceID)
  }
  let windowState = WindowState()
  windowState.activeSpaceID = spaceID
  return FavoritesStripView()
    .environment(windowState)
    .environment(favorites)
    .environment(store.activeSpace!.tabManager)
    .frame(width: 240)
}
