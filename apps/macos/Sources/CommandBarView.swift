import AppKit
import BrowserCore
import SwiftUI

/// The Arc/Spotlight-style command-bar overlay (⌘L / ⌘T): a centered translucent panel with an
/// auto-focused field that, as you type, mixes a navigate/search action with matching open tabs
/// (ranked across every Space). Enter acts on the highlight, arrows move it, Tab accepts the top
/// result, Escape / click-outside dismiss.
///
/// Ranking lives in `BrowserCore`'s ``SuggestionEngine``; this view only snapshots the live tabs into
/// `OpenTab`s, renders the results, and routes the chosen action back into `SpaceStore`.
struct CommandBarView: View {
  @Environment(SpaceStore.self) private var store
  @Environment(WindowState.self) private var windowState
  @Environment(CommandBarController.self) private var controller
  @Environment(HistoryStore.self) private var history
  @Environment(FavoritesStore.self) private var favoritesStore
  @Environment(AppSettings.self) private var appSettings
  @Environment(\.openWindow) private var openWindow

  @State private var searchText = ""
  @State private var selectedIndex = 0
  @FocusState private var fieldFocused: Bool

  /// Built from the configured search engine so the bar's URL/search action agrees with the address
  /// bar on what a typed string means.
  private var engine: SuggestionEngine {
    SuggestionEngine(parser: URLBarParser(searchTemplate: appSettings.searchTemplate))
  }

  /// All tabs across every Space, flattened for the ranker. Selecting one switches Space + tab.
  private var openTabs: [OpenTab] {
    store.spaces.flatMap { space in
      space.tabManager.tabs.map { OpenTab(id: $0.id, title: $0.title, url: $0.url) }
    }
  }

  /// This window's active Space's favorites, mapped for the ranker (favorites are per-Space).
  private var favorites: [FavoriteItem] {
    favoritesStore.all(spaceID: windowState.activeSpaceID).map {
      FavoriteItem(id: $0.id, title: $0.title, url: $0.url)
    }
  }

  private var suggestions: [Suggestion] {
    // Hand the engine a recent slice of history as candidates; it filters/ranks by the query.
    engine.suggestions(for: searchText, openTabs: openTabs,
                       favorites: favorites, history: history.recent(limit: 200))
  }

  var body: some View {
    ZStack(alignment: .top) {
      // Click-outside backdrop.
      Color.black.opacity(0.18)
        .ignoresSafeArea()
        .onTapGesture { controller.dismiss() }

      panel
        .frame(width: 560)
        .padding(.top, 140)
    }
    .onChange(of: searchText) { selectedIndex = 0 }
    .onAppear {
      searchText = controller.initialText
      selectedIndex = 0
      // Defer focus a tick so the field reliably becomes first responder, then select the
      // pre-filled URL (Arc-style) so the user can just start typing to replace it.
      DispatchQueue.main.async {
        fieldFocused = true
        if !controller.initialText.isEmpty { selectAll() }
      }
    }
  }

  // MARK: - Panel

  private var panel: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .imageScale(.large)

        TextField("Search or enter address", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 18))
          .focused($fieldFocused)
          .onSubmit(activateSelection)
          .onKeyPress(.escape) { controller.dismiss(); return .handled }
          .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
          .onKeyPress(.downArrow) { moveSelection(1); return .handled }
          .onKeyPress(.tab) { acceptTop(); return .handled }
      }
      .padding(16)

      if !suggestions.isEmpty {
        Divider()
        resultsList
      }
    }
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    .shadow(radius: 30, y: 12)
  }

  private var resultsList: some View {
    VStack(spacing: 2) {
      ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
        SuggestionRow(suggestion: suggestion, isSelected: index == selectedIndex)
          .contentShape(Rectangle())
          .onTapGesture { activate(suggestion) }
          .onHover { hovering in if hovering { selectedIndex = index } }
      }
    }
    .padding(8)
  }

  // MARK: - Keyboard

  private func moveSelection(_ delta: Int) {
    guard !suggestions.isEmpty else { return }
    let count = suggestions.count
    selectedIndex = (selectedIndex + delta + count) % count
  }

  /// Return: act on the highlighted suggestion (if any).
  private func activateSelection() {
    guard suggestions.indices.contains(selectedIndex) else { return }
    activate(suggestions[selectedIndex])
  }

  /// Tab: accept the top suggestion regardless of the current highlight.
  private func acceptTop() {
    if let first = suggestions.first { activate(first) }
  }

  // MARK: - Actions

  private func activate(_ suggestion: Suggestion) {
    switch suggestion.kind {
    case let .navigate(url), let .search(url), let .history(url), let .favorite(url):
      open(url)
    case let .switchToTab(tabID):
      switchToTab(tabID)
    }
    controller.dismiss()
  }

  /// Load `url` per how the bar was opened: a new tab for ⌘T, the current tab for ⌘L. Targets this
  /// window's active Space.
  private func open(_ url: URL) {
    guard let manager = windowState.activeSpace(in: store)?.tabManager else { return }
    switch controller.mode {
    case .newTab: manager.newTab(url: url)
    case .currentTab: manager.activeTab?.load(url)
    }
  }

  /// Find the Space owning `tabID` and reveal the tab. If that Space is open in another window, focus
  /// that window (where the tab lives); otherwise switch this window to it and select the tab.
  private func switchToTab(_ tabID: UUID) {
    for space in store.spaces where space.tabManager.tabs.contains(where: { $0.id == tabID }) {
      windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
      if windowState.activeSpaceID == space.id { space.tabManager.select(tabID) }
      return
    }
  }

  /// Selects the whole field (Arc-like) so the pre-filled URL is replaced on first keystroke. SwiftUI
  /// has no direct hook, so route `selectAll:` to the focused editor — same trick as `ToolbarView`.
  private func selectAll() {
    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
  }
}

/// One result row: an icon for the action kind, a primary title, and a secondary URL/query line.
private struct SuggestionRow: View {
  let suggestion: Suggestion
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: iconName)
        .frame(width: 20)
        .foregroundStyle(isSelected ? Color.white : .secondary)

      VStack(alignment: .leading, spacing: 1) {
        Text(suggestion.title)
          .lineLimit(1)
        if !suggestion.subtitle.isEmpty {
          Text(suggestion.subtitle)
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .foregroundStyle(isSelected ? Color.white : Color.primary)
    .background(isSelected ? Color.accentColor : Color.clear,
                in: RoundedRectangle(cornerRadius: 8))
  }

  private var iconName: String {
    switch suggestion.kind {
    case .navigate: return "globe"
    case .search: return "magnifyingglass"
    case .switchToTab: return "square.on.square"
    case .history: return "clock"
    case .favorite: return "star"
    }
  }
}
