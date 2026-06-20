import SwiftUI
import BrowserCore

/// The horizontal tab strip across the top of the window (Safari style). Pinned tabs render compact on
/// the left at a fixed width; the open tabs then divide the remaining width **equally** (two tabs split
/// the strip 50/50) down to a minimum width, after which the strip scrolls horizontally. The new-tab
/// "+" lives in the window toolbar (see `BrowserWindowView`), not here. The active chip is tinted with
/// the active Space's color.
///
/// Reads the active Space's `TabManager` from the environment (injected by `BrowserWindowView`), plus
/// `SpaceStore`/`WindowState` for the active Space's tint.
struct TabStripView: View {
  @Environment(TabManager.self) private var manager
  @Environment(SpaceStore.self) private var store
  @Environment(WindowState.self) private var windowState

  /// Smallest an open (unpinned) tab shrinks to before the strip starts scrolling instead.
  private let minTabWidth: CGFloat = 90
  /// Fixed width of a pinned (compact, icon-only) chip.
  private let pinnedWidth: CGFloat = 40

  private var tint: Color {
    let hex = windowState.activeSpace(in: store)?.colorHex ?? SpaceStore.defaultColorHex
    return SpaceColor.color(hex)
  }

  var body: some View {
    GeometryReader { geo in
      let pinned = manager.pinnedTabs
      let open = manager.unpinnedTabs
      // Width available to the open tabs after the pinned chips and inter-chip spacing.
      let spacing: CGFloat = 4
      let count = max(open.count, 1)
      let pinnedTotal = CGFloat(pinned.count) * (pinnedWidth + spacing)
      let available = geo.size.width - 16 - pinnedTotal
      let idealOpen = (available - CGFloat(count - 1) * spacing) / CGFloat(count)
      // Equal split when it fits; clamp to the minimum and let the ScrollView scroll past that.
      let openWidth = max(idealOpen, minTabWidth)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: spacing) {
          ForEach(pinned) { tab in
            TabChip(tab: tab, tint: tint, compact: true)
              .frame(width: pinnedWidth)
          }
          ForEach(open) { tab in
            TabChip(tab: tab, tint: tint, compact: false)
              .frame(width: openWidth)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: geo.size.width, alignment: .leading)
      }
    }
    .frame(height: 36)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
  }
}

/// One tab in the top strip: favicon (with a globe fallback), title (hidden when pinned/compact), and a
/// close button on hover. Tapping selects the tab; the active tab is tinted with the Space color. The
/// chip's width is set by `TabStripView`, so the content fills whatever space it's given.
private struct TabChip: View {
  let tab: WebTab
  let tint: Color
  let compact: Bool

  @Environment(TabManager.self) private var manager
  @Environment(WindowState.self) private var windowState
  @Environment(FavoritesStore.self) private var favorites
  @State private var hovering = false

  private var isActive: Bool { manager.activeTabID == tab.id }

  var body: some View {
    ZStack {
      // Centered favicon + title (Safari-style), filling the chip.
      HStack(spacing: 6) {
        favicon
        if !compact {
          Text(tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title)
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, compact ? 0 : 22)  // leave room for the leading close button

      // Close button overlays the leading edge on hover, so it never shifts the centered title.
      if hovering && !compact {
        HStack {
          Button {
            manager.closeTab(tab.id)
          } label: {
            Image(systemName: "xmark")
              .imageScale(.small)
          }
          .buttonStyle(.borderless)
          .help("Close Tab")
          Spacer()
        }
        .padding(.leading, 8)
      }
    }
    .padding(.vertical, 5)
    .frame(maxWidth: .infinity)
    .background(chipBackground)
    .contentShape(Capsule())
    .onHover { hovering = $0 }
    .onTapGesture { manager.select(tab.id) }
    .help(tab.title.isEmpty ? (tab.url?.absoluteString ?? "New Tab") : tab.title)
    .contextMenu { contextMenu }
  }

  /// The site favicon, falling back to a tinted globe while loading or when the page declares none.
  @ViewBuilder
  private var favicon: some View {
    if let url = tab.faviconURL {
      AsyncImage(url: url) { image in
        image.resizable().interpolation(.medium)
      } placeholder: {
        globe
      }
      .frame(width: 16, height: 16)
    } else {
      globe
    }
  }

  private var globe: some View {
    Image(systemName: "globe")
      .imageScale(.small)
      .foregroundStyle(isActive ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
      .frame(width: 16, height: 16)
  }

  /// Capsule chip background. The active tab is a solid, slightly raised pill (macOS HIG tab-bar /
  /// segmented-control selection); hovering an inactive tab shows a faint capsule; idle is clear.
  @ViewBuilder
  private var chipBackground: some View {
    if isActive {
      Capsule()
        .fill(Color(nsColor: .controlBackgroundColor))
        .overlay(Capsule().strokeBorder(.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
    } else if hovering {
      Capsule().fill(Color.secondary.opacity(0.12))
    } else {
      Capsule().fill(.clear)
    }
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

    let isGlobalFavorite = tab.url.map { favorites.contains(url: $0, in: nil) } ?? false
    Button(isGlobalFavorite ? "Remove from Favorites (All Spaces)" : "Add to Favorites (All Spaces)") {
      guard let url = tab.url else { return }
      favorites.toggle(url: url, title: tab.title, spaceID: nil)
    }
    .disabled(tab.url == nil)

    Divider()

    Button("Close Tab", role: .destructive) {
      manager.closeTab(tab.id)
    }
  }
}
