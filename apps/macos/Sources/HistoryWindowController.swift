import Foundation

/// Drives the ⌘Y History sheet. Owned at the app level (like `CommandBarController`) so the
/// `.commands` menu can open it and `BrowserWindowView` can present it from one shared flag.
@Observable
@MainActor
final class HistoryWindowController {
  var isPresented = false

  func present() { isPresented = true }
  func dismiss() { isPresented = false }
}
