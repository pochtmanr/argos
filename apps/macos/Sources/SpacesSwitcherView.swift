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

  var body: some View {
    VStack(spacing: 2) {
      ForEach(store.spaces) { space in
        spaceRow(space)
      }

      newSpaceButton
    }
    .padding(8)
    .background(.bar)
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
  }

  // MARK: - Rows

  private func spaceRow(_ space: Space) -> some View {
    let isActive = space.id == windowState.activeSpaceID
    // Shown in another window? (Claimed by some window that isn't this one.)
    let elsewhere = store.windowDisplaying(space.id).map { $0 != windowState.id } ?? false
    let tint = SpaceColor.color(space.colorHex)
    return HStack(spacing: 8) {
      Image(systemName: space.icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(tint, in: RoundedRectangle(cornerRadius: 6))

      Text(space.name)
        .lineLimit(1)
        .truncationMode(.tail)
        .fontWeight(isActive ? .semibold : .regular)

      Spacer(minLength: 0)

      // Indicate spaces currently open in another window; tapping such a row focuses that window.
      if elsewhere {
        Image(systemName: "macwindow")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isActive ? tint.opacity(0.18) : Color.clear)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
    }
    .contextMenu { contextMenu(for: space) }
    .help(elsewhere ? "\(space.name) — open in another window" : space.name)
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

    Divider()

    Button("Delete Space", role: .destructive) {
      store.deleteSpace(space.id)
    }
  }

  // MARK: - New space

  private var newSpaceButton: some View {
    Button {
      let space = store.newSpaceWithHome(appSettings.homeURL)
      // Show the new Space in this window (claiming it), rather than only updating global state.
      windowState.switchTo(space.id, in: store) { openWindow(value: $0) }
    } label: {
      Label("New Space", systemImage: "plus")
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.secondary)
    .help("New Space (⌘⇧E)")
  }

  /// Bridges the optional `renamingSpaceID` to the `Bool` binding the rename alert expects.
  private var isRenaming: Binding<Bool> {
    Binding(
      get: { renamingSpaceID != nil },
      set: { if !$0 { renamingSpaceID = nil } }
    )
  }
}

#Preview {
  let store = SpaceStore()
  return SpacesSwitcherView()
    .environment(store)
    .environment(WindowState())
    .environment(AppSettings())
    .frame(width: 240)
}
