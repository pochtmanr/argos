import AppKit
import BrowserCore
import SwiftUI

/// The centered address pill that lives in the window's native toolbar (Safari-style), driving the
/// active ``WebTab``: a leading search/favicon glyph, an editable URL/search field, and a trailing
/// reload/stop button. A thin progress underline tracks page loads, and the pill shows a blue focus
/// ring while editing. Glassed via Liquid Glass on macOS 26, with a translucent-material fallback.
///
/// Back/forward buttons are separate toolbar items (see `BrowserWindowView`); this view is just the URL
/// field so it can sit in the toolbar's `.principal` slot and stretch across the title bar.
struct AddressBarView: View {
  /// The tab being controlled. Read-only `@Observable` state; this view only reads it and calls its
  /// navigation methods, so no `@Bindable` is needed.
  let tab: WebTab

  /// Drives the URL-vs-search parser's search engine, so changing the engine in Settings takes effect
  /// on the very next address-bar submit.
  @Environment(AppSettings.self) private var appSettings

  /// Favorites live inside the address pill now (Safari-style trailing star), so the field reads the
  /// store directly to toggle/reflect the current page's starred state.
  @Environment(FavoritesStore.self) private var favorites
  /// Supplies the active Space ID, so a plain star targets this Space (⌥ targets All Spaces).
  @Environment(WindowState.self) private var windowState

  /// The address field's editable text. Mirrors `tab.url` when unfocused; holds the user's typing
  /// while focused.
  @State private var text = ""
  @FocusState private var addressFocused: Bool

  var body: some View {
    HStack(spacing: 6) {
      leadingIcon

      TextField("Search or enter website name", text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .focused($addressFocused)
        .onSubmit(commit)
        .onKeyPress(.escape) {
          syncTextToURL()
          addressFocused = false
          return .handled
        }

      favoriteButton

      Button {
        if tab.isLoading { tab.stop() } else { tab.reload() }
      } label: {
        Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
          .imageScale(.small)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
      .help(tab.isLoading ? "Stop" : "Reload")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(minWidth: 280, idealWidth: 560, maxWidth: 720)
    .addressGlass(focused: addressFocused)
    .overlay(alignment: .bottom) { progressUnderline }
    .help(tab.title.isEmpty ? (tab.url?.absoluteString ?? "") : tab.title)
    .onAppear(perform: syncTextToURL)
    .onChange(of: tab.url) {
      // Reflect programmatic navigation (clicks, back/forward) — but never clobber active typing.
      if !addressFocused { syncTextToURL() }
    }
    .onChange(of: addressFocused) { _, focused in
      if focused {
        selectAll()
      } else {
        // Focus left without committing (Return) — restore the current URL.
        syncTextToURL()
      }
    }
  }

  /// Trailing favorites star inside the pill. A plain click stars the page into the active Space;
  /// ⌥-click targets All Spaces (`spaceID: nil`). Filled/yellow when the page is a favorite in either
  /// scope. Mirrors the ⌘D "Add to Favorites" command.
  @ViewBuilder
  private var favoriteButton: some View {
    let inSpace = tab.url.map { favorites.contains(url: $0, in: windowState.activeSpaceID) } ?? false
    let inGlobal = tab.url.map { favorites.contains(url: $0, in: nil) } ?? false
    let isFavorite = inSpace || inGlobal
    Button {
      guard let url = tab.url else { return }
      let allSpaces = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
      favorites.toggle(url: url, title: tab.title, spaceID: allSpaces ? nil : windowState.activeSpaceID)
    } label: {
      Image(systemName: isFavorite ? "star.fill" : "star")
        .imageScale(.small)
        .foregroundStyle(isFavorite ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
    }
    .buttonStyle(.borderless)
    .disabled(tab.url == nil)
    .help(isFavorite ? "Remove from Favorites" : "Add to Favorites (⌥ for All Spaces)")
  }

  /// Magnifying glass while editing (Safari-style), otherwise the page favicon (globe fallback).
  @ViewBuilder
  private var leadingIcon: some View {
    if addressFocused || text.isEmpty {
      Image(systemName: "magnifyingglass")
        .imageScale(.small)
        .foregroundStyle(.secondary)
    } else if let favicon = tab.faviconURL {
      AsyncImage(url: favicon) { image in
        image.resizable().interpolation(.medium)
      } placeholder: {
        Image(systemName: "globe").imageScale(.small).foregroundStyle(.secondary)
      }
      .frame(width: 16, height: 16)
    } else {
      Image(systemName: "globe").imageScale(.small).foregroundStyle(.secondary)
    }
  }

  /// A thin tinted underline that fills left-to-right with load progress, hidden when idle.
  @ViewBuilder
  private var progressUnderline: some View {
    if tab.isLoading {
      GeometryReader { geo in
        Capsule()
          .fill(.tint)
          .frame(width: max(0, geo.size.width * tab.estimatedProgress), height: 2)
      }
      .frame(height: 2)
      .padding(.horizontal, 8)
      .allowsHitTesting(false)
    }
  }

  // MARK: - Actions

  private func commit() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let parser = URLBarParser(searchTemplate: appSettings.searchTemplate)
    tab.load(parser.resolve(trimmed))
    addressFocused = false
  }

  private func syncTextToURL() {
    text = tab.url?.absoluteString ?? ""
  }

  /// Selects the whole address (Arc-like) when the field gains focus. SwiftUI has no direct hook,
  /// so route a `selectAll:` action to the focused field's editor on the next runloop tick.
  private func selectAll() {
    DispatchQueue.main.async {
      NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }
  }
}

private extension View {
  /// Adds the blue focus ring while editing (Safari-style). On macOS 26 the toolbar's `.principal`
  /// item already sits on the system's Liquid Glass surface, so we add no background of our own —
  /// layering a second capsule here produced a visible "pillow on a pillow". On older macOS the
  /// toolbar has no glass, so a single translucent-material capsule stands in.
  @ViewBuilder
  func addressGlass(focused: Bool) -> some View {
    let ring = Capsule().strokeBorder(Color.accentColor, lineWidth: focused ? 3 : 0)
    if #available(macOS 26.0, *) {
      self.overlay(ring)
    } else {
      self
        .background(.regularMaterial, in: Capsule())
        .overlay(ring)
    }
  }
}
