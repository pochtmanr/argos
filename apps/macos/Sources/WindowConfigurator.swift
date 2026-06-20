import AppKit
import SwiftUI

/// Bridges to the hosting `NSWindow` to give the browser its Arc-style chrome: a transparent,
/// title-less titlebar over a full-size content view, so the `NavigationSplitView` sidebar runs the
/// full height of the window with the traffic lights insetting over its vibrancy. SwiftUI keeps the
/// sidebar's top content clear of the lights via the window's safe area.
///
/// Used as a zero-size `.background(WindowConfigurator())`, so every window (multi-window) configures
/// the window it lands in. `updateNSView` re-applies the settings, so they survive view updates; the
/// flags themselves are stable across resize and fullscreen (AppKit manages the traffic-light inset
/// and restores the titlebar on exit), so no per-resize work is needed.
struct WindowConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    // The window isn't attached yet at make-time; defer to the next runloop tick so `view.window`
    // resolves, then apply.
    DispatchQueue.main.async { [weak view] in
      guard let window = view?.window else { return }
      Self.configure(window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    // Re-apply on updates in case the view was re-hosted into a different window.
    DispatchQueue.main.async { [weak nsView] in
      guard let window = nsView?.window else { return }
      Self.configure(window)
    }
  }

  /// Applies the transparent / full-height-content titlebar configuration. Idempotent, so calling it
  /// repeatedly (make + update) is harmless.
  private static func configure(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    // Let content (the split view) draw under the titlebar so the sidebar is full-height.
    window.styleMask.insert(.fullSizeContentView)
  }
}
