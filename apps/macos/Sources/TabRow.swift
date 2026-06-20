import SwiftUI
import BrowserCore

/// One row in the vertical tab sidebar: favicon placeholder, title (falling back to host/URL), and a
/// close button that appears on hover. Selection highlighting is handled natively by the enclosing
/// `List`, so this view only renders content and exposes the close affordance.
struct TabRow: View {
  let tab: WebTab

  @Environment(TabManager.self) private var manager
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 8) {
      // Favicon affordance — placeholder for now; real favicons arrive later.
      Image(systemName: "globe")
        .foregroundStyle(.secondary)

      Text(tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title)
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer(minLength: 4)

      // Close affordance stays hidden until hover to keep the row uncluttered. ⌘W closes the active
      // tab via the app menu; this targets any row directly.
      if hovering {
        Button {
          manager.closeTab(tab.id)
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Close Tab")
      }
    }
    // Make the whole row hit-testable so taps anywhere select it (List handles the selection).
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

#Preview {
  let manager = TabManager()
  return List {
    TabRow(tab: manager.newTab(url: homeURL))
  }
  .environment(manager)
}
