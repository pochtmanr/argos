import SwiftUI
import BrowserCore

/// The space-creation dialog. Presented from the Spaces switcher's `+` button and the `⌘⇧E` menu
/// command. It asks the one product question first — **New from scratch** vs **Duplicate existing** —
/// then takes a name. A from-scratch space is a clean isolated identity (no accounts logged in); a
/// duplicate clones the chosen space's appearance, proxy, open tabs, and signed-in cookies.
///
/// This view is a pure form: it owns only its draft state and hands the result back through `onCreate`.
/// The host performs the actual creation (sync for scratch, async for duplicate, which copies cookies).
struct CreateSpaceSheet: View {
  enum Mode: String, CaseIterable, Identifiable {
    case scratch
    case duplicate
    var id: String { rawValue }
    var label: String { self == .scratch ? "New from scratch" : "Duplicate existing" }
  }

  /// Candidate sources for duplication, in display order (includes Personal — duplicating it makes an
  /// isolated copy of the main user's logins).
  let spaces: [Space]
  let onCancel: () -> Void
  /// `(mode, sourceID, name)` — `sourceID` is non-nil only for `.duplicate`.
  let onCreate: (Mode, Space.ID?, String) -> Void

  @State private var mode: Mode = .scratch
  @State private var name = "New Space"
  @State private var sourceID: Space.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("New Space")
        .font(.headline)

      Picker("Create mode", selection: $mode) {
        ForEach(Mode.allCases) { Text($0.label).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if mode == .duplicate {
        Picker("Duplicate from", selection: $sourceID) {
          ForEach(spaces) { space in
            Label(space.name, systemImage: space.icon).tag(Optional(space.id))
          }
        }
        Text("Copies appearance, proxy, open tabs, and signed-in cookies from the chosen space. Some sites that don't use cookies for sessions may still require signing in again.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Starts empty — no accounts logged in and nothing saved, with its own isolated cookies.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      TextField("Name", text: $name)
        .textFieldStyle(.roundedBorder)

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { onCancel() }
          .keyboardShortcut(.cancelAction)
        Button("Create") { onCreate(mode, sourceID, trimmedName) }
          .keyboardShortcut(.defaultAction)
          .disabled(!canCreate)
      }
    }
    .padding(20)
    .frame(width: 360)
    .onAppear { if sourceID == nil { sourceID = spaces.first?.id } }
    .onChange(of: mode) { _, newMode in adjustNameForMode(newMode) }
  }

  /// Suggests a sensible default name when toggling modes, but never clobbers a name the user typed.
  private func adjustNameForMode(_ newMode: Mode) {
    switch newMode {
    case .duplicate:
      let source = spaces.first { $0.id == sourceID } ?? spaces.first
      if name.isEmpty || name == "New Space", let source { name = "\(source.name) copy" }
    case .scratch:
      if name.hasSuffix(" copy") { name = "New Space" }
    }
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var canCreate: Bool {
    guard !trimmedName.isEmpty else { return false }
    return mode == .scratch || sourceID != nil
  }
}
