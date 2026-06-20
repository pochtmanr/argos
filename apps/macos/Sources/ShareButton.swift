import AppKit
import SwiftUI

/// A toolbar share button that presents the macOS share sheet (`NSSharingServicePicker`) for the
/// current page URL. The picker must anchor to a real `NSView`/rect, which SwiftUI buttons don't expose,
/// so this is an `NSViewRepresentable` hosting a plain `NSButton`; tapping it shows the picker anchored
/// to itself. Disabled when there's no URL to share.
struct ShareButton: NSViewRepresentable {
  /// The page URL to share; `nil` disables the button (e.g. a blank new tab).
  let url: URL?

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton()
    button.bezelStyle = .texturedRounded
    button.isBordered = false
    button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
    button.imagePosition = .imageOnly
    button.toolTip = "Share"
    button.target = context.coordinator
    button.action = #selector(Coordinator.share(_:))
    return button
  }

  func updateNSView(_ button: NSButton, context: Context) {
    context.coordinator.url = url
    button.isEnabled = url != nil
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(url: url)
  }

  final class Coordinator: NSObject, NSSharingServicePickerDelegate {
    var url: URL?

    init(url: URL?) {
      self.url = url
    }

    @objc func share(_ sender: NSButton) {
      guard let url else { return }
      let picker = NSSharingServicePicker(items: [url])
      picker.delegate = self
      picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
  }
}
