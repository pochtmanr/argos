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

  init() {
    // Seed the first space's tab with the home page at construction time (the store/manager stay
    // URL-agnostic). Spaces created later seed their home page in `newSpaceWithHome()`, so no tab is
    // ever left blank — replacing the old per-window `.onAppear` heuristic.
    let store = SpaceStore()
    store.activeSpace?.tabManager.activeTab?.load(homeURL)
    _store = State(initialValue: store)
  }

  var body: some Scene {
    WindowGroup {
      BrowserWindowView()
        .environment(store)
    }
    .commands {
      CommandMenu("Tab") {
        Button("New Tab") {
          store.activeSpace?.tabManager.newTab(url: homeURL)
        }
        .keyboardShortcut("t")

        Button("Close Tab") {
          if let manager = store.activeSpace?.tabManager, let id = manager.activeTabID {
            manager.closeTab(id)
          }
        }
        .keyboardShortcut("w")

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
    }
  }

  private func switchToSpace(at index: Int) {
    guard store.spaces.indices.contains(index) else { return }
    store.switchTo(store.spaces[index].id)
  }
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
