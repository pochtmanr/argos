import SwiftUI

/// Publishes the focused window's `WindowState` so the app's `.commands` menu can act on whichever
/// browser window is frontmost (⌘T, ⌘L, ⌘1–9, etc. all target the focused window).
private struct WindowStateFocusedKey: FocusedValueKey {
  typealias Value = WindowState
}

extension FocusedValues {
  var windowState: WindowState? {
    get { self[WindowStateFocusedKey.self] }
    set { self[WindowStateFocusedKey.self] = newValue }
  }
}
