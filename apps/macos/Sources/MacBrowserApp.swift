import AppKit
import SwiftUI
import BrowserCore

/// The page a fresh tab opens. Shared by the menu commands and the views so they agree on what
/// "new tab" / "new space" means. `BrowserCore` stays URL-agnostic.
let homeURL = URL(string: "https://www.apple.com")!

@main
struct MacBrowserApp: App {
  /// Owned here (not in `BrowserWindowView`) so the `.commands` menu can drive the same spaces/tabs
  /// the UI shows. `SpaceStore` is the top-level owner; each `Space` owns its own `TabManager`, so a
  /// tab lives in exactly one space.
  @State private var store: SpaceStore

  /// Debounced autosave: persists the live `store` to SwiftData on meaningful changes.
  @State private var autosaver: SessionAutosaver

  /// Drives the ⌘L / ⌘T command-bar overlay. Owned here (like `store`) so the `.commands` below and
  /// `BrowserWindowView` share one source of truth for whether the bar is open and how.
  @State private var commandBar = CommandBarController()

  /// Records browsing history and backs the command bar's history suggestions + the History view.
  /// Shares the persistence container so history lives in the same store file.
  @State private var historyStore: HistoryStore

  /// Drives the ⌘Y History sheet, owned here so the `.commands` menu and `BrowserWindowView` agree.
  @State private var historyController = HistoryWindowController()

  /// Per-Space favorites, backing the sidebar strip, the ⌘D toggle, and command-bar suggestions.
  /// Shares the persistence container so favorites live in the same store file.
  @State private var favoritesStore: FavoritesStore

  /// The on-disk session store. Optional so a storage failure never blocks launch — the app just
  /// runs without persistence for that session.
  private let persistence: SessionPersistence?

  init() {
    // Build the store and honor the dev reset flag before loading, so `BROWSER_RESET_STORE=1` (or the
    // Debug → Reset Store menu item) starts from a clean slate.
    let persistence = try? SessionPersistence()

    // History shares the persistence container; an in-memory store is the fallback when persistence
    // is unavailable (an in-memory SwiftData container effectively never fails to build).
    let historyStore = persistence?.makeHistoryStore() ?? (try! HistoryStore(inMemory: true))

    if ProcessInfo.processInfo.environment["BROWSER_RESET_STORE"] != nil {
      persistence?.reset()
      historyStore.clear(since: nil)
    }

    // Favorites share the persistence container (in-memory fallback when unavailable). Created after
    // the reset above so its cache reflects the post-reset store.
    let favoritesStore = persistence?.makeFavoritesStore() ?? (try! FavoritesStore(inMemory: true))

    // Restore the previous session if one exists; otherwise seed a fresh default space and load the
    // home page into its tab (first-run behavior). Restored tabs are lazy — `BrowserWindowView` loads
    // each one the first time it becomes active.
    let store: SpaceStore
    if let restored = persistence?.load() {
      store = restored
    } else {
      store = SpaceStore()
      store.activeSpace?.tabManager.activeTab?.load(homeURL)
    }

    // Record committed navigations into history. Set after restore so every tab (restored or new)
    // reports through the cascade down `SpaceStore → TabManager → WebTab`.
    store.historyRecorder = { [weak historyStore] url, title in
      historyStore?.record(url: url, title: title)
    }

    self.persistence = persistence
    _store = State(initialValue: store)
    _historyStore = State(initialValue: historyStore)
    _favoritesStore = State(initialValue: favoritesStore)
    _autosaver = State(initialValue: SessionAutosaver(store: store) { snapshot in
      persistence?.save(snapshot)
    })
  }

  var body: some Scene {
    WindowGroup {
      BrowserWindowView()
        .environment(store)
        .environment(commandBar)
        .environment(historyStore)
        .environment(historyController)
        .environment(favoritesStore)
        // Flush the debounced autosave on quit so the last change isn't lost to the debounce window.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
          autosaver.flush()
        }
    }
    .commands {
      CommandMenu("Tab") {
        // ⌘L opens the command bar pre-filled with the current URL (selected) to navigate, search,
        // or jump to an open tab.
        Button("Open Location…") {
          commandBar.presentForCurrentURL(store.activeSpace?.tabManager.activeTab?.url)
        }
        .keyboardShortcut("l")

        // ⌘T opens the command bar empty; submitting creates a new tab (so ⌘T then Esc adds nothing).
        Button("New Tab") {
          commandBar.presentForNewTab()
        }
        .keyboardShortcut("t")

        Button("Close Tab") {
          if let manager = store.activeSpace?.tabManager, let id = manager.activeTabID {
            manager.closeTab(id)
          }
        }
        .keyboardShortcut("w")

        Divider()

        // ⌘D toggles the active page in the current Space's favorites (add if absent, remove if saved).
        Button("Add to Favorites") {
          guard let tab = store.activeSpace?.tabManager.activeTab, let url = tab.url else { return }
          favoritesStore.toggle(url: url, title: tab.title, spaceID: store.activeSpace?.id)
        }
        .keyboardShortcut("d")

        // ⌃⌘P pins/unpins the active tab. ⌃⌘ avoids ⌘P (Print) and the Spaces menu's ⌘-digit set.
        Button("Toggle Pin") {
          if let manager = store.activeSpace?.tabManager, let id = manager.activeTabID {
            manager.togglePin(id)
          }
        }
        .keyboardShortcut("p", modifiers: [.command, .control])

        Divider()

        Button("Show Next Tab") {
          store.activeSpace?.tabManager.selectNext()
        }
        .keyboardShortcut("]", modifiers: [.command, .shift])

        Button("Show Previous Tab") {
          store.activeSpace?.tabManager.selectPrevious()
        }
        .keyboardShortcut("[", modifiers: [.command, .shift])
      }

      CommandMenu("Spaces") {
        Button("New Space") {
          store.newSpaceWithHome()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])

        Divider()

        // ⌘1…⌘9 jump to space N, greyed out for spaces that don't exist yet (so ⌘5 with three
        // spaces is a clear no-op). ⌘ rather than the prompt's ⌃ avoids the macOS Mission Control
        // "Switch to Desktop N" collision.
        ForEach(1...9, id: \.self) { n in
          Button("Switch to Space \(n)") {
            switchToSpace(at: n - 1)
          }
          .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
          .disabled(n > store.spaces.count)
        }
      }

      CommandMenu("History") {
        // ⌘Y opens the History sheet (searchable list of visited pages, grouped by day).
        Button("Show History") {
          historyController.present()
        }
        .keyboardShortcut("y")
      }

      #if DEBUG
      // Developer aid: wipe the persisted store and start over. Mirrors the `BROWSER_RESET_STORE`
      // launch flag but available at runtime.
      CommandMenu("Debug") {
        Button("Reset Store") { resetStore() }
      }
      #endif
    }
  }

  private func switchToSpace(at index: Int) {
    guard store.spaces.indices.contains(index) else { return }
    store.switchTo(store.spaces[index].id)
  }

  #if DEBUG
  /// Clears the persisted store and replaces the live session with a fresh default space, re-arming
  /// the autosaver on the new store so subsequent edits persist.
  private func resetStore() {
    persistence?.reset()
    historyStore.clear(since: nil)
    favoritesStore.refresh()
    let fresh = SpaceStore()
    fresh.historyRecorder = { [weak historyStore] url, title in
      historyStore?.record(url: url, title: title)
    }
    fresh.activeSpace?.tabManager.activeTab?.load(homeURL)
    persistence?.save(fresh)
    store = fresh
    autosaver = SessionAutosaver(store: fresh) { persistence?.save($0) }
  }
  #endif
}

extension SpaceStore {
  /// App-level convenience: create a space (with a rotating accent color so new spaces look
  /// distinct) and load the home page into its seeded tab. Lives in the app layer because
  /// `BrowserCore` doesn't know the home URL.
  @discardableResult
  func newSpaceWithHome() -> Space {
    let colorHex = SpaceColor.palette[spaces.count % SpaceColor.palette.count]
    let space = newSpace(name: "New Space", colorHex: colorHex)
    space.tabManager.activeTab?.load(homeURL)
    return space
  }
}
