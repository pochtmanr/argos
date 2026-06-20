import SwiftUI
import BrowserCore

/// The app menu bar. Every per-window action targets the **focused** window via
/// `@FocusedValue(\.windowState)`, while shared data lives in the injected `store`/`favoritesStore`.
/// Lives in its own `Commands` type (rather than inline in `MacBrowserApp`) precisely so it can read
/// the focused window — `@FocusedValue` resolves against the key window's published `WindowState`.
struct BrowserCommands: Commands {
  let store: SpaceStore
  let favoritesStore: FavoritesStore
  let appSettings: AppSettings

  @Environment(\.openWindow) private var openWindow
  @FocusedValue(\.windowState) private var window

  var body: some Commands {
    // ⌘N opens a brand-new browser window; it claims its Space on appear (first unclaimed, else new).
    CommandGroup(replacing: .newItem) {
      Button("New Window") {
        openWindow(value: WindowState.ID())
      }
      .keyboardShortcut("n")
    }

    CommandMenu("Tab") {
      Button("Open Location…") {
        window?.commandBar.presentForCurrentURL(activeTab?.url)
      }
      .keyboardShortcut("l")
      .disabled(window == nil)

      Button("New Tab") {
        activeManager?.newTab()
      }
      .keyboardShortcut("t")
      .disabled(window == nil)

      Button("Close Tab") {
        if let id = activeManager?.activeTabID { activeManager?.closeTab(id) }
      }
      .keyboardShortcut("w")
      .disabled(window == nil)

      Divider()

      Button("Add to Favorites") {
        guard let tab = activeTab, let url = tab.url else { return }
        favoritesStore.toggle(url: url, title: tab.title, spaceID: activeSpace?.id)
      }
      .keyboardShortcut("d")
      .disabled(window == nil)

      Button("Add to Favorites in All Spaces") {
        guard let tab = activeTab, let url = tab.url else { return }
        favoritesStore.toggle(url: url, title: tab.title, spaceID: nil)
      }
      .keyboardShortcut("d", modifiers: [.command, .option])
      .disabled(window == nil)

      Button("Toggle Pin") {
        if let id = activeManager?.activeTabID { activeManager?.togglePin(id) }
      }
      .keyboardShortcut("p", modifiers: [.command, .control])
      .disabled(window == nil)

      Divider()

      Button("Show Next Tab") { activeManager?.selectNext() }
        .keyboardShortcut("]", modifiers: [.command, .shift])
        .disabled(window == nil)

      Button("Show Previous Tab") { activeManager?.selectPrevious() }
        .keyboardShortcut("[", modifiers: [.command, .shift])
        .disabled(window == nil)
    }

    CommandMenu("View") {
      // ⌥⌘S toggles the focused window's sidebar (avoids the system Toggle-Sidebar item's ⌃⌘S). This
      // is the menu-discoverable twin of the toolbar's sidebar button.
      Button("Toggle Sidebar") { toggleSidebar() }
        .keyboardShortcut("s", modifiers: [.command, .option])
        .disabled(window == nil)

      Button("Proxy Panel") { window?.toggleRightPanel(.proxy) }
        .keyboardShortcut("p", modifiers: [.command, .option])
        .disabled(window == nil)

      Button("AI Panel") { window?.toggleRightPanel(.ai) }
        .keyboardShortcut("i", modifiers: [.command, .option])
        .disabled(window == nil)

      Divider()

      // ⌘R reloads (or stops, mid-load) the active tab — same toggle as the toolbar's reload button.
      Button("Reload Page") {
        guard let tab = activeTab else { return }
        if tab.isLoading { tab.stop() } else { tab.reload() }
      }
      .keyboardShortcut("r")
      .disabled(activeTab == nil)

      // ⌘[ / ⌘] walk the active tab's history, greyed out at the ends. (Tab cycling is ⌘⇧[ / ⌘⇧].)
      Button("Back") { activeTab?.goBack() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(activeTab?.canGoBack != true)

      Button("Forward") { activeTab?.goForward() }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(activeTab?.canGoForward != true)
    }

    CommandMenu("Spaces") {
      Button("New Space…") {
        // Open the creation sheet (scratch vs duplicate + name) in the focused window's sidebar.
        window?.wantsNewSpaceSheet = true
      }
      .keyboardShortcut("e", modifiers: [.command, .shift])
      .disabled(window == nil)

      Divider()

      ForEach(1...9, id: \.self) { n in
        Button("Switch to Space \(n)") { switchToSpace(at: n - 1) }
          .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
          .disabled(window == nil || n > store.spaces.count)
      }
    }

    CommandMenu("History") {
      Button("Show History") { window?.history.present() }
        .keyboardShortcut("y")
        .disabled(window == nil)
    }

    CommandMenu("Downloads") {
      Button("Show Downloads") { window?.downloads.toggle() }
        .keyboardShortcut("j", modifiers: [.command, .shift])
        .disabled(window == nil)
    }
  }

  // MARK: - Focused-window helpers

  private var activeSpace: Space? { window?.activeSpace(in: store) }
  private var activeManager: TabManager? { activeSpace?.tabManager }
  private var activeTab: WebTab? { activeManager?.activeTab }

  /// Flips the focused window's sidebar visibility, matching the toolbar button's behavior.
  private func toggleSidebar() {
    guard let window else { return }
    withAnimation {
      window.columnVisibility = window.columnVisibility == .all ? .detailOnly : .all
    }
  }

  /// Switch the focused window to space `index`; if that space is open in another window, focus that
  /// window instead of stealing it.
  private func switchToSpace(at index: Int) {
    guard let window, store.spaces.indices.contains(index) else { return }
    window.switchTo(store.spaces[index].id, in: store) { openWindow(value: $0) }
  }
}
