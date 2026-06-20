import Foundation

/// Drives the downloads popover. Owned at the app level (like `HistoryWindowController`) so the
/// `.commands` menu (⌘⇧J) and `BrowserWindowView`'s toolbar button present it from one shared flag.
@Observable
@MainActor
final class DownloadsController {
  var isPresented = false

  func present() { isPresented = true }
  func dismiss() { isPresented = false }
  func toggle() { isPresented.toggle() }
}
