import SwiftUI
import BrowserCore

/// The Spaces switcher pinned at the bottom of the sidebar: one colored row per space (active
/// highlighted), a "New Space" button, and a context menu to rename / recolor / change icon /
/// delete. Tapping a row switches the active space, which swaps the visible tab set.
struct SpacesSwitcherView: View {
  @Environment(SpaceStore.self) private var store
  /// This window's local state — selecting a row switches *this* window's Space (or focuses the
  /// window that already owns it).
  @Environment(WindowState.self) private var windowState
  /// Focuses an existing window (by its `WindowState.ID` value) when a Space is open elsewhere.
  @Environment(\.openWindow) private var openWindow
  /// Supplies the configurable home page for the "New Space" button.
  @Environment(AppSettings.self) private var appSettings

  /// When non-nil, the rename alert is shown for this space; `renameText` holds the edited name.
  @State private var renamingSpaceID: Space.ID?
  @State private var renameText = ""
  /// Tracks which space card the pointer is over so inactive cards can highlight on hover.
  @State private var hoveringSpaceID: Space.ID?

  var body: some View {
    VStack(spacing: 6) {
      // The Personal profile (the main user's identity) is pinned at the top, set apart from the
      // isolated spaces below it.
      if let personal = store.personalSpace {
        spaceRow(personal)
        if store.spaces.contains(where: { !$0.isPersonal }) {
          Divider().padding(.vertical, 4)
        }
      }

      ForEach(store.spaces.filter { !$0.isPersonal }) { space in
        spaceRow(space)
      }

      newSpaceButton
    }
    .padding(10)
    .alert("Rename Space", isPresented: isRenaming) {
      TextField("Name", text: $renameText)
      Button("Cancel", role: .cancel) { renamingSpaceID = nil }
      Button("Rename") {
        if let id = renamingSpaceID {
          store.rename(id, to: renameText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        renamingSpaceID = nil
      }
    }
    .sheet(isPresented: createSheetBinding) {
      CreateSpaceSheet(
        spaces: store.spaces,
        onCancel: { windowState.wantsNewSpaceSheet = false },
        onCreate: { mode, sourceID, name in createSpace(mode: mode, sourceID: sourceID, name: name) }
      )
    }
  }

  /// Performs the creation the `CreateSpaceSheet` requested, then shows the new space in this window.
  /// Duplication is async (it copies the source's cookies), so it runs in a `Task`.
  private func createSpace(mode: CreateSpaceSheet.Mode, sourceID: Space.ID?, name: String) {
    windowState.wantsNewSpaceSheet = false
    switch mode {
    case .scratch:
      let space = store.newSpaceWithHome(appSettings.homeURL)
      store.rename(space.id, to: name)
      windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
    case .duplicate:
      guard let sourceID, let source = store.spaces.first(where: { $0.id == sourceID }) else { return }
      Task {
        let space = await store.duplicateSpace(source, name: name)
        windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
      }
    }
  }

  // MARK: - Rows

  private func spaceRow(_ space: Space) -> some View {
    let isActive = space.id == windowState.activeSpaceID
    // Shown in another window? (Claimed by some window that isn't this one.)
    let elsewhere = store.windowDisplaying(space.id).map { $0 != windowState.id } ?? false
    let hovering = hoveringSpaceID == space.id
    let tint = SpaceColor.color(space.colorHex)
    return HStack(spacing: 10) {
      Image(systemName: space.icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(tint, in: RoundedRectangle(cornerRadius: 7))

      Text(space.name)
        .lineLimit(1)
        .truncationMode(.tail)
        .fontWeight(isActive ? .semibold : .regular)

      Spacer(minLength: 0)

      // Indicate spaces currently open in another window (tapping focuses that window); otherwise a
      // small tinted dot marks the active space.
      if elsewhere {
        Image(systemName: "macwindow")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      } else if isActive {
        Circle()
          .fill(tint)
          .frame(width: 6, height: 6)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(spaceCardBackground(isActive: isActive, hovering: hovering, tint: tint))
    .shadow(color: .black.opacity(isActive ? 0.12 : 0), radius: 3, y: 1)
    .contentShape(RoundedRectangle(cornerRadius: 12))
    .onHover { hoveringSpaceID = $0 ? space.id : (hoveringSpaceID == space.id ? nil : hoveringSpaceID) }
    .onTapGesture {
      windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
    }
    .contextMenu { contextMenu(for: space) }
    .help(elsewhere ? "\(space.name) — open in another window" : space.name)
  }

  /// Three-state card surface mirroring the top tab chips: the active space is elevated on a
  /// `controlBackgroundColor` fill with a tinted border, hovered cards get a faint wash, and idle
  /// cards stay clear.
  @ViewBuilder
  private func spaceCardBackground(isActive: Bool, hovering: Bool, tint: Color) -> some View {
    if isActive {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(nsColor: .controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.55), lineWidth: 1))
    } else {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.secondary.opacity(hovering ? 0.10 : 0))
    }
  }

  @ViewBuilder
  private func contextMenu(for space: Space) -> some View {
    Button("Rename…") {
      renameText = space.name
      renamingSpaceID = space.id
    }

    Menu("Color") {
      ForEach(SpaceColor.palette, id: \.self) { hex in
        Button {
          store.recolor(space.id, to: hex)
        } label: {
          Label {
            Text(hex)
          } icon: {
            Image(systemName: space.colorHex == hex ? "checkmark.circle.fill" : "circle.fill")
              .foregroundStyle(SpaceColor.color(hex))
          }
        }
      }
    }

    Menu("Icon") {
      ForEach(SpaceColor.icons, id: \.self) { icon in
        Button {
          store.setIcon(space.id, to: icon)
        } label: {
          Label(icon, systemImage: icon)
        }
      }
    }

    // The Personal profile is the main user's identity and can't be deleted.
    if !space.isPersonal {
      Divider()

      Button("Delete Space", role: .destructive) {
        store.deleteSpace(space.id)
      }
    }
  }

  // MARK: - New space

  private var newSpaceButton: some View {
    Button {
      // Open the creation sheet (scratch vs duplicate + name) instead of creating immediately.
      windowState.wantsNewSpaceSheet = true
    } label: {
      Label("New Space", systemImage: "plus")
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
              Color.secondary.opacity(0.4),
              style: StrokeStyle(lineWidth: 1, dash: [4])
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .padding(.top, 2)
    .help("New Space (⌘⇧E)")
  }

  /// Bridges the optional `renamingSpaceID` to the `Bool` binding the rename alert expects.
  private var isRenaming: Binding<Bool> {
    Binding(
      get: { renamingSpaceID != nil },
      set: { if !$0 { renamingSpaceID = nil } }
    )
  }

  /// Bridges this window's `wantsNewSpaceSheet` flag to the `Bool` binding the `.sheet` expects, so the
  /// `+` button and the `⌘⇧E` menu command share one creation sheet.
  private var createSheetBinding: Binding<Bool> {
    Binding(
      get: { windowState.wantsNewSpaceSheet },
      set: { windowState.wantsNewSpaceSheet = $0 }
    )
  }
}

#Preview {
  let store = SpaceStore()
  let work = store.newSpaceWithHome(URL(string: "https://www.swift.org")!)
  store.rename(work.id, to: "Work")
  store.recolor(work.id, to: "#8B5CF6")
  store.setIcon(work.id, to: "briefcase")
  let reading = store.newSpaceWithHome(URL(string: "https://www.apple.com")!)
  store.rename(reading.id, to: "Reading")
  store.recolor(reading.id, to: "#F59E0B")
  store.setIcon(reading.id, to: "book")
  return ScrollView { SpacesSwitcherView() }
    .environment(store)
    .environment(WindowState())
    .environment(AppSettings())
    .frame(width: 240)
}
