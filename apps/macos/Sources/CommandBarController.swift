import Foundation

/// Drives the ⌘L / ⌘T command-bar overlay. Owned at the app level (like `SpaceStore`) so the
/// `.commands` menu and the views agree on whether the bar is open and how it was opened.
///
/// The bar is presented in two modes: ``Mode/currentTab`` (⌘L) acts on the active tab and is
/// pre-filled with its URL; ``Mode/newTab`` (⌘T) opens empty and creates a fresh tab on submit. The
/// new tab is only created when the user actually acts, so ⌘T followed by Escape changes nothing.
@Observable
@MainActor
final class CommandBarController {
  enum Mode {
    /// Navigate/search loads into the current tab (⌘L).
    case currentTab
    /// Navigate/search opens a new tab (⌘T).
    case newTab
  }

  private(set) var isPresented = false
  /// Text the field starts with when the bar opens (the current URL for ⌘L, empty for ⌘T).
  private(set) var initialText = ""
  private(set) var mode: Mode = .currentTab

  /// ⌘L: open pre-filled with the current URL (the view selects it so typing replaces it).
  func presentForCurrentURL(_ url: URL?) {
    mode = .currentTab
    initialText = url?.absoluteString ?? ""
    isPresented = true
  }

  /// ⌘T: open empty; submitting navigates/searches into a brand-new tab.
  func presentForNewTab() {
    mode = .newTab
    initialText = ""
    isPresented = true
  }

  func dismiss() {
    isPresented = false
  }
}
