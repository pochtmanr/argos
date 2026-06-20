import SwiftUI
import BrowserCore

/// The page a fresh tab opens. Shared by the menu commands and `BrowserWindowView` so they agree on
/// what "new tab" means. `BrowserCore`'s `TabManager` stays URL-agnostic.
let homeURL = URL(string: "https://www.apple.com")!

@main
struct MacBrowserApp: App {
  /// Owned here (not in `ContentView`) so the `.commands` menu can drive the same tabs the UI shows.
  @State private var manager = TabManager()

  var body: some Scene {
    WindowGroup {
      BrowserWindowView()
        .environment(manager)
    }
    .commands {
      CommandMenu("Tab") {
        Button("New Tab") {
          manager.newTab(url: homeURL)
        }
        .keyboardShortcut("t")

        Button("Close Tab") {
          if let id = manager.activeTabID {
            manager.closeTab(id)
          }
        }
        .keyboardShortcut("w")

        Divider()

        Button("Show Next Tab") {
          manager.selectNext()
        }
        .keyboardShortcut("]", modifiers: [.command, .shift])

        Button("Show Previous Tab") {
          manager.selectPrevious()
        }
        .keyboardShortcut("[", modifiers: [.command, .shift])
      }
    }
  }
}
