import SwiftUI
import BrowserCore

/// The right-side inspector column. Renders whichever panel `WindowState.rightPanel` selects (proxy or
/// AI) with a shared header + close button, at a fixed width. `BrowserWindowView` shows this beside
/// the web view only when a panel is open.
struct RightPanelView: View {
  @Environment(WindowState.self) private var windowState

  /// Fixed inspector width, matching common macOS side panels.
  static let width: CGFloat = 320

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        Button {
          windowState.rightPanel = nil
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Close Panel")
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider()

      switch windowState.rightPanel {
      case .proxy:
        ProxyPanelView()
      case .ai:
        AIPanelView()
      case nil:
        Spacer()
      }
    }
    .frame(width: Self.width)
    .background(.bar)
  }

  private var title: String {
    switch windowState.rightPanel {
    case .proxy: "Proxy"
    case .ai: "AI Assistant"
    case nil: ""
    }
  }
}
