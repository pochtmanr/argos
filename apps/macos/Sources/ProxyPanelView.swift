import SwiftUI
import BrowserCore

/// The Proxy inspector panel: shows and edits the **active Space's** proxy. Per-space scope means a
/// proxy set here routes every tab in the current Space (and persists with it). Paste a proxy string,
/// toggle it on, and Apply — `SpaceStore.setProxy` rebuilds the Space's data store and reloads its
/// tabs through the new route.
struct ProxyPanelView: View {
  @Environment(SpaceStore.self) private var store
  @Environment(WindowState.self) private var windowState

  /// Editable draft of the proxy string; seeded from the active Space and on Space change.
  @State private var draft = ""
  @State private var enabled = false

  private var space: Space? { windowState.activeSpace(in: store) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if let space {
          Label("Routing \(space.name)", systemImage: space.icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 6) {
            Text("Proxy address")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("socks5://user:pass@host:1080", text: $draft)
              .textFieldStyle(.roundedBorder)
              .font(.system(.body, design: .monospaced))
            Text("SOCKS5 by default. Prefix with http:// for an HTTP CONNECT proxy.")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }

          Toggle("Use proxy for this space", isOn: $enabled)

          HStack {
            Button("Apply") { apply() }
              .buttonStyle(.borderedProminent)
              .disabled(enabled && ProxyConfigParser.configuration(from: draft) == nil)
            Button("Clear") { clear() }
              .disabled(draft.isEmpty && !enabled && !(space.proxyEnabled))
            Spacer()
          }

          statusFooter(for: space)
        } else {
          Text("No active space.")
            .foregroundStyle(.secondary)
        }
      }
      .padding(12)
    }
    .onAppear(perform: sync)
    // Re-seed the draft when the window switches Space so the panel always reflects the current one.
    .onChange(of: windowState.activeSpaceID) { sync() }
  }

  @ViewBuilder
  private func statusFooter(for space: Space) -> some View {
    Divider()
    HStack(spacing: 6) {
      Circle()
        .fill(space.proxyEnabled ? Color.green : Color.secondary)
        .frame(width: 8, height: 8)
      Text(space.proxyEnabled ? "Active: \(space.proxyConfigString ?? "")" : "Direct connection")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
  }

  private func sync() {
    draft = space?.proxyConfigString ?? ""
    enabled = space?.proxyEnabled ?? false
  }

  private func apply() {
    guard let space else { return }
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    store.setProxy(space.id, string: trimmed.isEmpty ? nil : trimmed, enabled: enabled && !trimmed.isEmpty)
    sync()
  }

  private func clear() {
    guard let space else { return }
    store.setProxy(space.id, string: nil, enabled: false)
    sync()
  }
}
